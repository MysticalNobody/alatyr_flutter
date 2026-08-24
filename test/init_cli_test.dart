import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/init_rewrite.dart';

/// The CLI's refusal contract. init is destructive and self-deleting, so
/// every one of these runs happens in a throwaway directory: what is asserted
/// is that init stops with exit 2 and a message BEFORE it deletes anything.
///
/// The child process is `Platform.resolvedExecutable` - the same pinned SDK
/// that runs this test (what `fvm dart test` resolves to). `fvm dart` itself
/// cannot be used here: outside the repository there is no `.fvmrc`, so fvm
/// would fall back to a different SDK and fail on the language version.
void main() {
  final initScript = p.absolute('tool', 'init.dart');

  ProcessResult runCli(
    List<String> args, {
    required String workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
  }) => Process.runSync(
    Platform.resolvedExecutable,
    ['run', initScript, ...args],
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
  );

  String tempDir(String prefix) {
    final dir = Directory.systemTemp.createTempSync(prefix);
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir.path;
  }

  String gitRepo(String prefix) {
    final dir = tempDir(prefix);
    final init = Process.runSync('git', ['init', '-q'], workingDirectory: dir);
    expect(init.exitCode, 0, reason: '${init.stderr}');
    return dir;
  }

  test('a directory that is not a git checkout is exit 2 with a reason', () {
    final r = runCli([
      '--name',
      'my_app',
      '--org',
      'com.example',
      '--yes',
    ], workingDirectory: tempDir('init_cli_nogit'));
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    expect(r.stderr, contains('init must run inside a git checkout'));
    expect(r.stderr, isNot(contains('Unhandled exception')));
  });

  test('a subdirectory of a checkout is exit 2 naming the root', () {
    final root = gitRepo('init_cli_subdir');
    final sub = Directory(p.join(root, 'app'))..createSync();
    final r = runCli([
      '--name',
      'my_app',
      '--org',
      'com.example',
      '--yes',
    ], workingDirectory: sub.path);
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    expect(r.stderr, contains('run init from the repository root'));
    // The empty repo still has its pubspec-less root: nothing was touched.
    expect(Directory(sub.path).listSync(), isEmpty);
  });

  test('a missing git binary is a message, not a stack trace', () {
    final r = runCli(
      ['--name', 'my_app', '--org', 'com.example', '--yes'],
      workingDirectory: tempDir('init_cli_nogitbin'),
      environment: const {'PATH': '/nonexistent-bin'},
      includeParentEnvironment: false,
    );
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    expect(
      r.stderr,
      contains('init must run inside a git checkout (git not found)'),
    );
    expect(r.stderr, isNot(contains('ProcessException')));
  });

  test('an unusable --template-url is an argument error, exit 2', () {
    for (final bad in ['', 'nope', 'https://example.invalid/a(b)']) {
      final r = runCli([
        '--name',
        'my_app',
        '--org',
        'com.example',
        '--template-url',
        bad,
        '--yes',
      ], workingDirectory: gitRepo('init_cli_url'));
      expect(r.exitCode, 2, reason: '"$bad": ${r.stdout}${r.stderr}');
      expect(r.stderr, contains('--template-url'));
      expect(r.stderr, contains('only tracked files are rewritten'));
    }
  });

  /// A committed copy of the fixture template tree: the only repo state in
  /// which the CLI gets past its argument checks and reaches the worktree
  /// guard with a real identity to derive.
  String committedFixtureRepo(String prefix) {
    final dir = gitRepo(prefix);
    _copyFixtureTree(p.join('test', 'fixtures', 'init', 'template'), dir);
    for (final args in [
      ['add', '-A'],
      [
        '-c',
        'user.email=t@t',
        '-c',
        'user.name=t',
        '-c',
        'commit.gpgsign=false',
        'commit',
        '-qm',
        'fixture',
      ],
    ]) {
      final r = Process.runSync('git', args, workingDirectory: dir);
      expect(r.exitCode, 0, reason: '${r.stderr}');
    }
    return dir;
  }

  test('a dirty worktree is exit 2 before anything is deleted', () {
    final dir = committedFixtureRepo('init_cli_dirty');
    // Both flavors of dirt - an uncommitted edit and an untracked file: the
    // documented recovery command (git checkout -- . && git clean -fd)
    // would destroy exactly these.
    File(
      p.join(dir, 'README.md'),
    ).writeAsStringSync('local uncommitted work\n', mode: FileMode.append);
    File(p.join(dir, 'notes.txt')).writeAsStringSync('untracked scratch\n');
    final r = runCli([
      '--name',
      'my_app',
      '--org',
      'com.example',
      '--yes',
    ], workingDirectory: dir);
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    expect(r.stderr, contains('uncommitted changes'));
    expect(r.stderr, contains('README.md'));
    expect(r.stderr, contains('notes.txt'));
    // Nothing destructive ran: deleting template-only paths is runInit's
    // first step, so their survival proves the guard fired before it.
    expect(File(p.join(dir, 'tool', 'init.dart')).existsSync(), isTrue);
    expect(
      File(p.join(dir, 'docs', 'workflow', 'instantiation.md')).existsSync(),
      isTrue,
    );
  });

  test('status.showUntrackedFiles=no cannot blind the worktree guard', () {
    final dir = committedFixtureRepo('init_cli_dirty_hidden');
    // A supported git config that makes plain `git status --porcelain`
    // omit untracked files entirely - the guard must override it, or the
    // recovery command would still delete work the guard never saw.
    final config = Process.runSync('git', [
      'config',
      'status.showUntrackedFiles',
      'no',
    ], workingDirectory: dir);
    expect(config.exitCode, 0, reason: '${config.stderr}');
    File(p.join(dir, 'notes.txt')).writeAsStringSync('untracked scratch\n');
    final r = runCli([
      '--name',
      'my_app',
      '--org',
      'com.example',
      '--yes',
    ], workingDirectory: dir);
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    expect(r.stderr, contains('uncommitted changes'));
    expect(r.stderr, contains('notes.txt'));
    expect(File(p.join(dir, 'tool', 'init.dart')).existsSync(), isTrue);
  });

  test('argument errors outrank the worktree guard on a dirty tree', () {
    final dir = committedFixtureRepo('init_cli_dirty_args');
    File(p.join(dir, 'notes.txt')).writeAsStringSync('untracked scratch\n');
    final r = runCli([
      '--name',
      'my_app',
      '--org',
      'nope',
      '--yes',
    ], workingDirectory: dir);
    // The documented ordering: argument errors exit 2 BEFORE any tree
    // inspection, so the same bad input gets the same answer regardless of
    // worktree state.
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    expect(r.stderr, contains('usage:'));
    expect(r.stderr, isNot(contains('uncommitted changes')));
  });

  test('a long dirty list is truncated, not dumped wholesale', () {
    final dir = committedFixtureRepo('init_cli_dirty_many');
    for (var i = 0; i < 12; i++) {
      File(p.join(dir, 'scratch_$i.txt')).writeAsStringSync('untracked $i\n');
    }
    final r = runCli([
      '--name',
      'my_app',
      '--org',
      'com.example',
      '--yes',
    ], workingDirectory: dir);
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    expect(r.stderr, contains('uncommitted changes'));
    expect(r.stderr, contains('... and 2 more'));
  });

  test('git status failing outright is a message naming git, not a silent '
      'pass', () {
    final dir = committedFixtureRepo('init_cli_status_fail');
    // An index git cannot open: rev-parse (no index needed) still succeeds,
    // so this reaches exactly the status branch of the worktree guard.
    final r = runCli(
      ['--name', 'my_app', '--org', 'com.example', '--yes'],
      workingDirectory: dir,
      environment: {'GIT_INDEX_FILE': dir},
    );
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    expect(r.stderr, contains('git status failed'));
    expect(File(p.join(dir, 'tool', 'init.dart')).existsSync(), isTrue);
  });

  test('a tree dirtied while init waits at the confirmation prompt is '
      'refused', () async {
    final dir = committedFixtureRepo('init_cli_prompt_dirty');
    final proc = await Process.start(Platform.resolvedExecutable, [
      'run',
      initScript,
      '--name',
      'my_app',
      '--org',
      'com.example',
    ], workingDirectory: dir);
    final stderrText = proc.stderr.transform(utf8.decoder).join();
    final seen = StringBuffer();
    final prompt = Completer<void>();
    proc.stdout.transform(utf8.decoder).listen((chunk) {
      seen.write(chunk);
      if (!prompt.isCompleted && seen.toString().contains('Proceed?')) {
        prompt.complete();
      }
    });
    await prompt.future.timeout(const Duration(seconds: 60));
    // The clean check passed before the prompt; the answer must not be
    // allowed to authorize a rewrite of a tree that changed underneath it.
    File(
      p.join(dir, 'README.md'),
    ).writeAsStringSync('prompt-window edit\n', mode: FileMode.append);
    proc.stdin.writeln('y');
    await proc.stdin.close();
    final code = await proc.exitCode.timeout(const Duration(seconds: 60));
    expect(code, 2, reason: '$seen${await stderrText}');
    expect(await stderrText, contains('uncommitted changes'));
    expect(File(p.join(dir, 'tool', 'init.dart')).existsSync(), isTrue);
  });

  test(
    'a clean committed tree proceeds through the guard into the rewrite',
    () {},
    skip:
        'deliberate: the happy path runs dart pub get and tool/checks.sh '
        '--fast inside the fixture (network, minutes) - '
        'tool/template_smoke.sh owns it end to end on the real tree.',
  );

  test('--print-template-only-paths prints the list init deletes', () {
    final r = runCli([
      '--print-template-only-paths',
    ], workingDirectory: p.current);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(
      const LineSplitter().convert('${r.stdout}'),
      templateOnlyPaths,
      reason: 'tool/template_smoke.sh asserts on exactly this list',
    );
  });
}

/// Materialises the fixture tree, dropping the `.txt` suffix every fixture
/// file carries (same convention as test/init_rewrite_test.dart).
void _copyFixtureTree(String from, String to) {
  for (final entity in Directory(
    from,
  ).listSync(recursive: true, followLinks: false)) {
    final rel = p.relative(entity.path, from: from);
    if (entity is Directory) {
      Directory(p.join(to, rel)).createSync(recursive: true);
    } else if (entity is File) {
      final target = rel.endsWith('.txt')
          ? rel.substring(0, rel.length - 4)
          : rel;
      File(p.join(to, target))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}
