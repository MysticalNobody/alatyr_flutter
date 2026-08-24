import 'dart:io';

import 'src/init_identity.dart';
import 'src/init_rewrite.dart';
import 'src/init_validate.dart';

/// One-shot template instantiation (docs/workflow/instantiation.md).
/// Self-deleting: the
/// rewrite removes this file, its sources, its tests and the rest of
/// `templateOnlyPaths`. Run from the repository root of a git checkout.
///
/// `dart run tool/init.dart --name NAME --org ORG [--display-name TITLE]
/// [--template-url URL] [--yes]`, or `--print-identity` to print the derived
/// placeholder identity as `KEY='value'` lines (for scripts that must not
/// spell it, e.g. tool/template_smoke.sh), or `--print-template-only-paths`
/// to print the paths init deletes, one per line.
void main(List<String> args) {
  String? name;
  String? org;
  String? displayName;
  String? templateUrl;
  var yes = false;
  var printIdentity = false;
  var printTemplateOnlyPaths = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--name':
        name = _value(args, ++i, '--name');
      case '--org':
        org = _value(args, ++i, '--org');
      case '--display-name':
        displayName = _value(args, ++i, '--display-name');
      case '--template-url':
        templateUrl = _value(args, ++i, '--template-url');
      case '--yes':
        yes = true;
      case '--print-identity':
        printIdentity = true;
      case '--print-template-only-paths':
        printTemplateOnlyPaths = true;
      default:
        _usage('unknown argument ${args[i]}');
    }
  }
  if (printTemplateOnlyPaths) {
    // Printed BEFORE init deletes them, so tool/template_smoke.sh can assert
    // every one of them is gone without restating the list.
    templateOnlyPaths.forEach(stdout.writeln);
    return;
  }

  final root = Directory.current.path;
  // Everything below assumes the repository root: `git ls-files` prints paths
  // relative to the cwd and the identity is derived from files at the root,
  // so a run from a subdirectory would silently derive the wrong identity.
  _requireRepositoryRoot(root);

  if (printIdentity) {
    final from = _guarded(() => deriveIdentity(root));
    stdout
      ..writeln("PACKAGE_NAME='${from.packageName}'")
      ..writeln("BUNDLE_ID='${from.bundleId}'")
      ..writeln("ORG='${from.org}'")
      ..writeln("DISPLAY_NAME='${from.displayName}'")
      ..writeln("WORKSPACE_NAME='${from.workspaceName}'");
    return;
  }
  if (name == null || org == null) {
    _usage('--name and --org are required');
  }

  // Argument errors exit 2 before anything destructive happens - including
  // the ones that need the placeholder identity, so it is derived first
  // (reading the app shell touches nothing).
  final members = _guarded(() => workspaceMemberNames(root));
  final InitTarget to;
  try {
    if (templateUrl != null) {
      validateTemplateUrl(templateUrl);
    }
    to = validateTarget(
      name: name,
      org: org,
      displayName: displayName,
      workspaceMembers: members,
    );
  } on InitArgumentException catch (e) {
    _usage(e.message);
  }
  // Only now the placeholder, so an argument that is malformed on its own
  // stays exit 2 even in a tree init cannot derive an identity from.
  final from = _guarded(() => deriveIdentity(root));
  try {
    validateNotPlaceholder(
      to: to,
      placeholderOrg: from.org,
      placeholderPackageName: from.packageName,
      placeholderDisplayName: from.displayName,
      placeholderWorkspaceName: from.workspaceName,
    );
  } on InitArgumentException catch (e) {
    _usage(e.message);
  }
  final tracked = _trackedFiles(root);

  stdout
    ..writeln('Instantiating the template:')
    ..writeln('  package      ${from.packageName} -> ${to.name}')
    ..writeln(
      '  bundle id    ${from.bundleId} -> ${to.bundleIdSnake} (Apple: ${to.bundleIdCamel})',
    )
    ..writeln('  org          ${from.org} -> ${to.org}')
    ..writeln('  display name ${from.displayName} -> ${to.displayName}')
    ..writeln('  workspace    ${from.workspaceName} -> ${to.workspaceName}')
    ..writeln('Template machinery removed: ${templateOnlyPaths.join(', ')}');
  if (!yes) {
    stdout.write('Proceed? [y/N] ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    if (answer != 'y' && answer != 'yes') {
      stderr.writeln('aborted');
      exit(1);
    }
  }

  final report = _guarded(
    () => runInit(
      rootDir: root,
      from: from,
      to: to,
      trackedFiles: tracked,
      templateUrl: templateUrl,
    ),
    afterDestructive: true,
  );
  stdout.writeln(
    'Rewrote ${report.rewritten.length} files, moved ${report.movedDirs.length} directories, deleted ${report.deleted.length} paths.',
  );
  if (report.skipped.isNotEmpty) {
    stdout.writeln('Skipped (symlinks): ${report.skipped.join(', ')}');
  }

  // Documented final step: format what the rename touched, resolve, smoke.
  // `dart format` with an empty file list exits 64, so the whole step is
  // skipped when the rename touched no Dart file.
  if (report.changedDartFiles.isNotEmpty) {
    final format = formatChangedDart(
      rootDir: root,
      files: report.changedDartFiles,
      dartExecutable: Platform.resolvedExecutable,
    );
    if (format.exitCode != 0) {
      stderr.writeln('dart format failed: ${format.stderr}');
      _fail(
        'the rename left unformattable Dart sources',
        afterDestructive: true,
      );
    }
  }
  _run(root, ['pub', 'get'], 'dart pub get');
  _run(
    root,
    ['bash', 'tool/checks.sh', '--fast'],
    'tool/checks.sh --fast',
    shell: true,
  );
  stdout.writeln(
    'Done. Commit the result, then run the full gate: tool/checks.sh',
  );
}

String _value(List<String> args, int i, String flag) {
  if (i >= args.length || args[i].startsWith('--')) {
    _usage('$flag needs a value');
  }
  return args[i];
}

Never _usage(String message) {
  stderr
    ..writeln(message)
    ..writeln(
      'usage: dart run tool/init.dart --name NAME --org ORG [--display-name TITLE] [--template-url URL] [--yes] | --print-identity | --print-template-only-paths',
    )
    ..writeln(
      'Run it from the repository root of a git checkout: only tracked files are rewritten.',
    );
  exit(2);
}

/// Expected failures end as a message plus, after the destructive step, the
/// documented recovery command - never as a stack trace.
Never _fail(String message, {required bool afterDestructive}) {
  stderr.writeln(message);
  if (afterDestructive) {
    stderr.writeln('recover with: git checkout -- . && git clean -fd');
  }
  exit(1);
}

T _guarded<T>(T Function() body, {bool afterDestructive = false}) {
  try {
    return body();
  } on InitPostconditionException catch (e) {
    _fail(e.message, afterDestructive: afterDestructive);
  } on StateError catch (e) {
    _fail(e.message, afterDestructive: afterDestructive);
  } on FormatException catch (e) {
    // Malformed YAML (yaml's YamlException is a FormatException).
    _fail('$e', afterDestructive: afterDestructive);
  } on FileSystemException catch (e) {
    final path = e.path;
    _fail(
      path == null ? e.message : '${e.message}: $path',
      afterDestructive: afterDestructive,
    );
  }
}

/// `git rev-parse --show-toplevel` is the only thing that can tell a
/// subdirectory of a checkout from the checkout itself.
void _requireRepositoryRoot(String root) {
  final ProcessResult result;
  try {
    result = Process.runSync('git', [
      'rev-parse',
      '--show-toplevel',
    ], workingDirectory: root);
  } on ProcessException {
    stderr.writeln('init must run inside a git checkout (git not found)');
    exit(2);
  }
  if (result.exitCode != 0) {
    stderr.writeln('init must run inside a git checkout');
    exit(2);
  }
  final toplevel = (result.stdout as String).trim();
  if (_resolve(toplevel) != _resolve(root)) {
    stderr.writeln('run init from the repository root: $toplevel');
    exit(2);
  }
}

/// Compares directories, not strings: /tmp and /private/tmp are the same
/// directory on macOS.
String _resolve(String path) {
  try {
    return Directory(path).resolveSymbolicLinksSync();
  } on FileSystemException {
    return path;
  }
}

List<String> _trackedFiles(String root) {
  final result = Process.runSync('git', [
    'ls-files',
    '-z',
  ], workingDirectory: root);
  if (result.exitCode != 0) {
    stderr.writeln(
      'init must run inside a git checkout (git ls-files failed): ${result.stderr}',
    );
    exit(2);
  }
  return (result.stdout as String)
      .split('\u0000')
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Runs `dart <args>` with the SAME Dart that runs this script (the fvm pin
/// when invoked as `fvm dart run tool/init.dart`), or a shell command.
void _run(String root, List<String> args, String label, {bool shell = false}) {
  final result = shell
      ? Process.runSync(args.first, args.sublist(1), workingDirectory: root)
      : Process.runSync(
          Platform.resolvedExecutable,
          args,
          workingDirectory: root,
        );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr
      ..writeln('$label failed (exit ${result.exitCode})')
      // These steps run after the rewrite: the tree is already renamed.
      ..writeln(
        'the rename itself is done; fix the issue and re-run "$label", or '
        'start over with: git checkout -- . && git clean -fd',
      );
    exit(result.exitCode);
  }
}
