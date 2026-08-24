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
