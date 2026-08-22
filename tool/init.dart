import 'dart:io';

import 'src/init_identity.dart';
import 'src/init_rewrite.dart';
import 'src/init_validate.dart';

/// One-shot template instantiation (spec section 9). Self-deleting: the
/// rewrite removes this file, its sources, its tests and the template-only
/// CI. Run from the repository root of a git checkout.
///
/// `dart run tool/init.dart --name NAME --org ORG [--display-name TITLE]
/// [--template-url URL] [--yes]`, or `--print-identity` to print the derived
/// placeholder identity as `KEY='value'` lines (for scripts that must not
/// spell it, e.g. tool/template_smoke.sh).
void main(List<String> args) {
  String? name;
  String? org;
  String? displayName;
  String? templateUrl;
  var yes = false;
  var printIdentity = false;
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
      default:
        _usage('unknown argument ${args[i]}');
    }
  }
  final root = Directory.current.path;
  final from = deriveIdentity(root);
  if (printIdentity) {
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
  final tracked = _trackedFiles(root);
  final InitTarget to;
  try {
    to = validateTarget(name: name, org: org, displayName: displayName);
  } on InitArgumentException catch (e) {
    _usage(e.message);
  }

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

  final report = runInit(
    rootDir: root,
    from: from,
    to: to,
    trackedFiles: tracked,
    templateUrl: templateUrl,
  );
  stdout.writeln(
    'Rewrote ${report.rewritten.length} files, moved ${report.movedDirs.length} directories, deleted ${report.deleted.length} paths.',
  );

  // Spec section 9 step 7: format what the rename touched, resolve, smoke.
  final format = formatChangedDart(
    rootDir: root,
    files: report.changedDartFiles,
    dartExecutable: Platform.resolvedExecutable,
  );
  if (format.exitCode != 0) {
    stderr.writeln('dart format failed: ${format.stderr}');
    exit(format.exitCode);
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
      'usage: dart run tool/init.dart --name NAME --org ORG [--display-name TITLE] [--template-url URL] [--yes] | --print-identity',
    );
  exit(2);
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
    stderr.writeln('$label failed (exit ${result.exitCode})');
    exit(result.exitCode);
  }
}
