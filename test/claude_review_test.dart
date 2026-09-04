import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Exercise the real runner in throwaway repositories. The stub only replaces
/// the paid reviewer; Git preconditions, CLI restrictions and result parsing run
/// normally, so a shell invocation cannot silently approve an unreviewed scope.
void main() {
  final script = File('tool/claude_review.sh').absolute.path;
  final schema = File('.codex/review-schema.json').readAsStringSync();
  late Directory tmp;
  late String repo;
  late String out;
  late Map<String, String> env;

  Map<String, dynamic> review({String verdict = 'approve'}) => {
    'verdict': verdict,
    'summary': 'Stub reviewer completed this scope.',
    'findings': verdict == 'approve'
        ? <dynamic>[]
        : [
            <String, dynamic>{
              'title': '[P1] Await the operation',
              'body': 'The caller can exit before the operation completes.',
              'priority': 1,
              'confidence_score': 0.9,
              'code_location': {
                'filepath': 'first.txt',
                'line_range': {'start': 1, 'end': 1},
              },
            },
          ],
  };

  Map<String, dynamic> envelope(Map<String, dynamic> value) => {
    'type': 'result',
    'subtype': 'success',
    'is_error': false,
    'structured_output': value,
  };

  void respond(Object value) =>
      File('${tmp.path}/response.json').writeAsStringSync(jsonEncode(value));

  void git(List<String> args) {
    final result = Process.runSync(
      'git',
      args,
      workingDirectory: repo,
      environment: env,
    );
    expect(result.exitCode, 0, reason: '${args.join(' ')}: ${result.stderr}');
  }

  ProcessResult invoke(List<String> args) => Process.runSync(
    'bash',
    [script, ...args, '--out', out],
    workingDirectory: repo,
    environment: env,
  );

  ProcessResult run({bool structured = false, String base = 'base-ref'}) =>
      invoke(['--base', base, if (structured) '--structured']);

  List<String> recordedArgs() => File(
    '${tmp.path}/args',
  ).readAsStringSync().split('\u0000').where((arg) => arg.isNotEmpty).toList();

  String flagValue(List<String> args, String flag) {
    expect(args, contains(flag));
    final index = args.indexOf(flag);
    expect(index + 1, lessThan(args.length));
    return args[index + 1];
  }

  void expectNotInvoked() =>
      expect(File('${tmp.path}/args').existsSync(), isFalse);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('claude_review');
    repo = '${tmp.path}/repo';
    out = '${tmp.path}/out';
    final bin = Directory('${tmp.path}/bin')..createSync(recursive: true);
    final stub = File('${bin.path}/claude')
      ..writeAsStringSync(
        '#!/usr/bin/env bash\n'
        'set -euo pipefail\n'
        r'''printf '%s\0' "$@" > "$CLAUDE_STUB_ARGS"'''
        '\n'
        r'cat > "$CLAUDE_STUB_STDIN"'
        '\n'
        r'case "${CLAUDE_STUB_MUTATION:-}" in'
        '\n'
        r'  tracked) printf "concurrent edit\n" >> base.txt ;;'
        '\n'
        r'  untracked) printf "concurrent file\n" > concurrent.txt ;;'
        '\n'
        r'  head) git commit --allow-empty -qm "concurrent commit" ;;'
        '\n'
        'esac\n'
        r'cat "$CLAUDE_STUB_RESPONSE"'
        '\n'
        r'exit "${CLAUDE_STUB_EXIT:-0}"'
        '\n',
      );
    final chmod = Process.runSync('chmod', ['+x', stub.path]);
    expect(chmod.exitCode, 0);
    env = {
      'PATH': '${bin.path}:${Platform.environment['PATH'] ?? ''}',
      'GIT_AUTHOR_NAME': 'T',
      'GIT_AUTHOR_EMAIL': 't@example.com',
      'GIT_COMMITTER_NAME': 'T',
      'GIT_COMMITTER_EMAIL': 't@example.com',
      'GIT_CONFIG_GLOBAL': '/dev/null',
      'GIT_CONFIG_SYSTEM': '/dev/null',
      'GIT_CONFIG_NOSYSTEM': '1',
      'CLAUDE_STUB_ARGS': '${tmp.path}/args',
      'CLAUDE_STUB_STDIN': '${tmp.path}/stdin',
      'CLAUDE_STUB_RESPONSE': '${tmp.path}/response.json',
    };
    Directory('$repo/.claude').createSync(recursive: true);
    File('$repo/.claude/review-model').writeAsStringSync('stub-reviewer\n');
    Directory('$repo/.codex').createSync(recursive: true);
    File('$repo/.codex/review-schema.json').writeAsStringSync(schema);
    File('$repo/AGENTS.md').writeAsStringSync(
      '# Test repository\n\n'
      '## Code Review Rules\n\n'
      'Report P0/P1 failures only. REVIEW_RUBRIC_MARKER.\n',
    );
    File('$repo/base.txt').writeAsStringSync('base\n');
    git(['init', '-q']);
    git(['add', '-A']);
    git(['commit', '-qm', 'base']);
    git(['branch', 'base-ref']);
    File('$repo/first.txt').writeAsStringSync('first task change\n');
    git(['add', '-A']);
    git(['commit', '-qm', 'first task commit']);
    File('$repo/second.txt').writeAsStringSync('second task change\n');
    git(['add', '-A']);
    git(['commit', '-qm', 'second task commit']);
    respond(envelope(review()));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('structured review normalizes the successful CLI envelope', () {
    final result = run(structured: true);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect((result.stdout as String).trim(), '$out/review.json');
    expect(jsonDecode(File('$out/review.json').readAsStringSync()), review());
    expect(File('$out/review-response.json').existsSync(), isTrue);
    expect(File('$out/review.log').existsSync(), isTrue);
  });

  test('text review includes the verdict, summary and every finding', () {
    respond(envelope(review(verdict: 'request_changes')));
    final result = run();
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect((result.stdout as String).trim(), '$out/review.txt');
    expect(
      File('$out/review.txt').readAsStringSync(),
      allOf(
        contains('request_changes'),
        contains('Stub reviewer completed this scope.'),
        contains('[P1] Await the operation'),
        contains('The caller can exit before the operation completes.'),
        contains('first.txt'),
      ),
    );
  });

  test('reviewer receives a read-only role and the entire task diff', () {
    final result = run(structured: true);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final args = recordedArgs();
    expect(args, contains('-p'));
    expect(flagValue(args, '--model'), 'stub-reviewer');
    expect(flagValue(args, '--effort'), 'high');
    for (final flag in ['--tools', '--allowedTools']) {
      expect(flagValue(args, flag).split(',').toSet(), {
        'Read',
        'Grep',
        'Glob',
      });
    }
    expect(flagValue(args, '--permission-mode'), 'dontAsk');
    expect(args, contains('--disable-slash-commands'));
    expect(args, contains('--strict-mcp-config'));
    expect(args, contains('--no-session-persistence'));
    expect(args, isNot(contains('--dangerously-skip-permissions')));
    expect(flagValue(args, '--output-format'), 'json');
    expect(jsonDecode(flagValue(args, '--json-schema')), jsonDecode(schema));
    expect(jsonDecode(flagValue(args, '--mcp-config')), {
      'mcpServers': <String, dynamic>{},
    });
    final settings =
        jsonDecode(flagValue(args, '--settings')) as Map<String, dynamic>;
    expect(settings['disableAllHooks'], isTrue);
    final permissions = settings['permissions'] as Map<String, dynamic>;
    expect(permissions['deny'], contains('Read(/.dart-defines/*.env)'));
    final input = File('${tmp.path}/stdin').readAsStringSync();
    expect(input, contains('REVIEW_RUBRIC_MARKER'));
    expect(input, contains('diff --git a/first.txt b/first.txt'));
    expect(input, contains('diff --git a/second.txt b/second.txt'));
  });

  for (final args in <List<String>>[
    [],
    ['--base'],
    ['--base', '--structured'],
    ['--base', ''],
    ['--unknown'],
    ['--out'],
  ]) {
    test('invalid invocation $args returns usage error without review', () {
      final result = invoke(args);
      expect(result.exitCode, 2, reason: '${result.stderr}');
      expectNotInvoked();
    });
  }

  for (final state in ['modified', 'staged', 'untracked']) {
    test('$state changes cannot be omitted from the review scope', () {
      if (state == 'untracked') {
        File('$repo/new.txt').writeAsStringSync('unreviewed new content\n');
      } else {
        File('$repo/base.txt').writeAsStringSync('unreviewed modification\n');
        if (state == 'staged') git(['add', 'base.txt']);
      }
      final result = run();
      expect(result.exitCode, 3);
      expect(result.stderr, contains('uncommitted'));
      expectNotInvoked();
    });
  }

  for (final base in ['no-such-ref', 'HEAD:base.txt', 'HEAD']) {
    test('invalid or empty scope $base cannot produce a verdict', () {
      final result = run(base: base);
      expect(result.exitCode, 3, reason: '${result.stderr}');
      expectNotInvoked();
      expect(File('$out/review.txt').existsSync(), isFalse);
    });
  }

  test('CLI failure cannot reuse a stale approval', () {
    Directory(out).createSync(recursive: true);
    File('$out/review.json').writeAsStringSync(jsonEncode(review()));
    env['CLAUDE_STUB_EXIT'] = '7';
    final result = run(structured: true);
    expect(result.exitCode, 3);
    expect(File('$out/review.json').existsSync(), isFalse);
  });

  for (final mutation in ['tracked', 'untracked', 'head']) {
    test('concurrent $mutation mutation invalidates the reviewed scope', () {
      env['CLAUDE_STUB_MUTATION'] = mutation;
      final result = run(structured: true);
      expect(result.exitCode, 3, reason: '${result.stderr}');
      expect(File('${tmp.path}/args').existsSync(), isTrue);
      expect(File('$out/review.json').existsSync(), isFalse);
    });
  }

  test('exit zero with empty output cannot reuse a stale text verdict', () {
    Directory(out).createSync(recursive: true);
    File('$out/review.txt').writeAsStringSync('approve\n');
    File('${tmp.path}/response.json').writeAsStringSync('');
    final result = run();
    expect(result.exitCode, 3);
    expect(File('$out/review.txt').existsSync(), isFalse);
  });

  test('malformed JSON is a failed review', () {
    File('${tmp.path}/response.json').writeAsStringSync('{not json');
    final result = run(structured: true);
    expect(result.exitCode, 3);
    expect(File('$out/review.json').existsSync(), isFalse);
  });

  for (final failure in [
    'error result',
    'error subtype',
    'missing structured output',
    'invalid verdict',
    'invalid findings',
  ]) {
    test('$failure is not accepted as a successful review', () {
      final value = envelope(review());
      switch (failure) {
        case 'error result':
          value['is_error'] = true;
        case 'error subtype':
          value['subtype'] = 'error_max_turns';
        case 'missing structured output':
          value.remove('structured_output');
        case 'invalid verdict':
          value['structured_output'] = review()..['verdict'] = 'looks good';
        case 'invalid findings':
          value['structured_output'] = review()..['findings'] = 'none';
      }
      respond(value);
      final result = run(structured: true);
      expect(result.exitCode, 3, reason: '${result.stderr}');
      expect(File('$out/review.json').existsSync(), isFalse);
    });
  }

  test(
    'request_changes is a completed structured review, not a CLI failure',
    () {
      final findings = review(verdict: 'request_changes');
      respond(envelope(findings));
      final result = run(structured: true);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(jsonDecode(File('$out/review.json').readAsStringSync()), findings);
    },
  );

  test('an approval containing a P1 finding cannot pass as valid output', () {
    final findings = review(verdict: 'request_changes')
      ..['verdict'] = 'approve';
    respond(envelope(findings));
    final result = run(structured: true);
    expect(result.exitCode, 3, reason: '${result.stderr}');
    expect(File('$out/review.json').existsSync(), isFalse);
  });

  for (final failure in [
    'whitespace-only summary',
    'finding missing a required property',
    'finding with an unknown property',
    'negative priority',
    'fractional priority',
    'confidence above one',
    'null code location',
    'blank filepath',
    'reversed line range',
    'missing is_error',
    'string is_error',
    'wrong envelope type',
    'request_changes without findings',
  ]) {
    test('$failure cannot produce a review artifact', () {
      final structured = review(verdict: 'request_changes');
      final value = envelope(structured);
      final finding =
          (structured['findings'] as List<dynamic>).first
              as Map<String, dynamic>;
      final location = finding['code_location'] as Map<String, dynamic>;
      switch (failure) {
        case 'whitespace-only summary':
          structured['summary'] = ' \n\t ';
        case 'finding missing a required property':
          finding.remove('body');
        case 'finding with an unknown property':
          finding['unexpected'] = true;
        case 'negative priority':
          finding['priority'] = -1;
        case 'fractional priority':
          finding['priority'] = 0.5;
        case 'confidence above one':
          finding['confidence_score'] = 1.1;
        case 'null code location':
          finding['code_location'] = null;
        case 'blank filepath':
          location['filepath'] = '   ';
        case 'reversed line range':
          location['line_range'] = {'start': 3, 'end': 1};
        case 'missing is_error':
          value.remove('is_error');
        case 'string is_error':
          value['is_error'] = 'false';
        case 'wrong envelope type':
          value['type'] = 'assistant';
        case 'request_changes without findings':
          structured['findings'] = <dynamic>[];
      }
      respond(value);
      final result = run(structured: true);
      expect(result.exitCode, 3, reason: '${result.stderr}');
      expect(File('$out/review.json').existsSync(), isFalse);
    });
  }
}
