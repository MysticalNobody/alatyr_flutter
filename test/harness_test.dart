import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// The harness's own invariants (AGENTS.md): the contract stays under
/// Codex's comfortable budget, Claude imports it rather than duplicating
/// it, and every path-scoped rule declares the paths it binds to.
void main() {
  test('AGENTS.md exists and is under 8 KB', () {
    final file = File('AGENTS.md');
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), lessThan(8192));
  });

  test('CLAUDE.md imports AGENTS.md on its first line', () {
    final lines = File('CLAUDE.md').readAsLinesSync();
    expect(lines.first, '@AGENTS.md');
  });

  test('AGENTS.md ends with the Code Review Rules section', () {
    final content = File('AGENTS.md').readAsStringSync();
    final index = content.indexOf('## Code Review Rules');
    expect(index, greaterThan(0));
    expect(
      content.indexOf('\n## ', index + 1),
      -1,
      reason: 'Code Review Rules must be the final section',
    );
  });

  test('every .claude/rules file declares paths: frontmatter', () {
    final rules = Directory('.claude/rules')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    expect(
      rules.map((f) => f.uri.pathSegments.last).toSet(),
      containsAll(<String>['testing.md', 'widgets.md', 'codegen.md']),
      reason:
          'the three shipped rule files must stay; a project may add more - '
          'the frontmatter loop below validates every file it finds',
    );
    for (final rule in rules) {
      final lines = rule.readAsLinesSync();
      expect(lines.first, '---', reason: '${rule.path} has no frontmatter');
      final end = lines.indexOf('---', 1);
      expect(
        end,
        greaterThan(1),
        reason: '${rule.path} frontmatter unterminated',
      );
      final frontmatter = lines.sublist(1, end);
      expect(frontmatter, contains('paths:'), reason: rule.path);
      expect(
        frontmatter.any((l) => RegExp(r'^\s+-\s+".+"$').hasMatch(l)),
        isTrue,
        reason: '${rule.path}: paths entries are quoted globs',
      );
    }
  });

  group('hook wiring', () {
    test(
      '.claude/settings.json wires both hooks to existing executable scripts and denies env reads',
      () {
        final settings =
            jsonDecode(File('.claude/settings.json').readAsStringSync())
                as Map<String, dynamic>;
        final hooks = settings['hooks'] as Map<String, dynamic>;
        final commands = <String>[];
        for (final event in ['PreToolUse', 'PostToolUse']) {
          final groups = hooks[event] as List<dynamic>;
          for (final group in groups.cast<Map<String, dynamic>>()) {
            expect(group['matcher'], 'Edit|Write');
            for (final h
                in (group['hooks'] as List<dynamic>)
                    .cast<Map<String, dynamic>>()) {
              expect(h['type'], 'command');
              commands.add(h['command'] as String);
            }
          }
        }
        expect(
          commands.any((c) => c.contains('tool/hooks/guard_generated.sh')),
          isTrue,
        );
        expect(
          commands.any((c) => c.contains('tool/hooks/format_dart.sh')),
          isTrue,
        );
        for (final script in [
          'tool/hooks/guard_generated.sh',
          'tool/hooks/format_dart.sh',
        ]) {
          final stat = File(script).statSync();
          expect(
            stat.mode & 0x49,
            0x49,
            reason: '$script must be executable (u+x,g+x,o+x)',
          );
        }
        final deny =
            (settings['permissions'] as Map<String, dynamic>)['deny']
                as List<dynamic>;
        expect(deny, contains('Read(/.dart-defines/*.env)'));
      },
    );

    test(
      '.codex/hooks.json wires both the guard and format scripts via the git root',
      () {
        final hooks =
            jsonDecode(File('.codex/hooks.json').readAsStringSync())
                as Map<String, dynamic>;
        String commandOf(String event) {
          final group =
              ((hooks['hooks'] as Map<String, dynamic>)[event] as List<dynamic>)
                  .cast<Map<String, dynamic>>();
          expect(group.single['matcher'], 'Edit|Write');
          return ((group.single['hooks'] as List<dynamic>).single
                  as Map<String, dynamic>)['command']
              as String;
        }

        final pre = commandOf('PreToolUse');
        expect(pre, contains('git rev-parse --show-toplevel'));
        expect(pre, contains('tool/hooks/guard_generated.sh'));

        final post = commandOf('PostToolUse');
        expect(post, contains('git rev-parse --show-toplevel'));
        expect(post, contains('tool/hooks/format_dart.sh'));
      },
    );
  });

  group('codex review protocol', () {
    test(
      'review-schema.json is a strict object schema everywhere (OpenAI structured outputs)',
      () {
        final schema =
            jsonDecode(File('.codex/review-schema.json').readAsStringSync())
                as Map<String, dynamic>;
        void assertStrict(Map<String, dynamic> node, String path) {
          final type = node['type'];
          final isObject =
              type == 'object' || (type is List && type.contains('object'));
          if (isObject) {
            expect(
              node['additionalProperties'],
              isFalse,
              reason: '$path: additionalProperties must be false',
            );
            final props = (node['properties'] as Map<String, dynamic>?) ?? {};
            expect(
              (node['required'] as List<dynamic>?)?.toSet(),
              props.keys.toSet(),
              reason: '$path: every property must be required',
            );
            for (final entry in props.entries) {
              assertStrict(
                entry.value as Map<String, dynamic>,
                '$path.${entry.key}',
              );
            }
          }
          if (node['items'] is Map<String, dynamic>) {
            assertStrict(node['items'] as Map<String, dynamic>, '$path[]');
          }
        }

        assertStrict(schema, r'$');
        expect(
          ((schema['properties'] as Map<String, dynamic>)['verdict']
              as Map<String, dynamic>)['enum'],
          ['approve', 'request_changes'],
        );
      },
    );

    test(
      '.codex/config.toml pins review_model and carries no profile table (ignored since Codex 0.134)',
      () {
        final config = File('.codex/config.toml').readAsStringSync();
        expect(
          RegExp(r'^\s*\[profiles', multiLine: true).hasMatch(config),
          isFalse,
        );
        // Shape, not value: rotating the pin is a documented one-file edit
        // (docs/workflow/maintenance.md), and it must not turn this suite red.
        expect(
          RegExp(r'^review_model = "[^"]+"$', multiLine: true).hasMatch(config),
          isTrue,
          reason:
              'a non-empty review_model pin must exist in .codex/config.toml',
        );
        // The script reads that same file, so the two cannot drift.
        final script = File(
          '.claude/skills/cross-review/codex_review.sh',
        ).readAsStringSync();
        final extractor = script
            .split('\n')
            .firstWhere((l) => l.startsWith('REVIEW_MODEL='), orElse: () => '');
        expect(
          extractor,
          allOf(contains('.codex/config.toml'), contains('review_model')),
          reason:
              'codex_review.sh must extract the pin from .codex/config.toml',
        );
      },
    );

    test('cross-review skill declares frontmatter and ships its script', () {
      final skill = File(
        '.claude/skills/cross-review/SKILL.md',
      ).readAsLinesSync();
      expect(skill.first, '---');
      expect(
        skill.sublist(1, skill.indexOf('---', 1)).join('\n'),
        allOf(contains('name: cross-review'), contains('description:')),
      );
      final script = File('.claude/skills/cross-review/codex_review.sh');
      expect(script.existsSync(), isTrue);
      expect(script.statSync().mode & 0x49, 0x49);
    });

    test(
      'codex_review.sh dirty-tree guard covers tracked AND untracked changes',
      () {
        // `git diff --quiet HEAD --` alone only sees tracked files (modified
        // or staged); a new file that was never `git add`-ed is invisible to
        // it, so the guard must also fail on untracked files, or a dirty
        // tree could silently narrow the reviewed diff (task 8 fix round 1).
        final script = File(
          '.claude/skills/cross-review/codex_review.sh',
        ).readAsStringSync();
        expect(script, contains('git diff --quiet HEAD --'));
        expect(script, contains('git ls-files --others --exclude-standard'));
        // Both checks must gate the same guard clause, not live in unrelated
        // branches.
        expect(
          RegExp(
            r'git diff --quiet HEAD --.*\|\|.*git ls-files --others --exclude-standard',
          ).hasMatch(script),
          isTrue,
          reason: 'the two checks must be OR-ed in one guard condition',
        );
      },
    );
  });

  // The dirty-tree guard and the exit-code contract, exercised for real:
  // a throwaway git repo plus a stub `codex` on PATH (grepping the script's
  // source text cannot show that the guard actually fires).
  group('codex_review.sh preconditions (temp repo, stub codex)', () {
    final script = File(
      '.claude/skills/cross-review/codex_review.sh',
    ).absolute.path;
    late Directory tmp;
    late String repo;
    late Map<String, String> env;

    String git(List<String> args) {
      final r = Process.runSync(
        'git',
        args,
        workingDirectory: repo,
        environment: env,
      );
      expect(r.exitCode, 0, reason: '${args.join(' ')}: ${r.stderr}');
      return (r.stdout as String).trim();
    }

    ProcessResult runArgs(
      List<String> args, {
      Map<String, String> overrides = const {},
    }) => Process.runSync(
      'bash',
      [script, ...args, '--out', '${tmp.path}/out'],
      workingDirectory: repo,
      environment: {...env, ...overrides},
    );

    ProcessResult run(String base) => runArgs(['--base', base]);

    List<String> reviewerArgs() => File('${tmp.path}/args').readAsLinesSync();

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('codex_review');
      repo = '${tmp.path}/repo';
      final bin = Directory('${tmp.path}/bin')..createSync(recursive: true);
      // Record arguments and stdin so successful tests prove the reviewed
      // range, not just that an output file happened to be written.
      File('${bin.path}/codex').writeAsStringSync(
        '#!/usr/bin/env bash\n'
        r'printf "%s\n" "$@" >> "$STUB_ARGS"'
        '\n'
        r'if [[ "$1" == "login" ]]; then'
        '\n'
        r'  [[ -z "${STUB_MOVE_REF:-}" ]] || git update-ref "$STUB_MOVE_REF" HEAD'
        '\n'
        r'  exit "${STUB_LOGIN_EXIT:-0}"; fi'
        '\n'
        r'cat > "$STUB_STDIN"'
        '\n'
        r'while [[ $# -gt 0 ]]; do'
        r' [[ "$1" == "-o" ]] && { echo stub > "$2"; exit 0; }; shift; done'
        '\nexit 1\n',
      );
      Process.runSync('chmod', ['+x', '${bin.path}/codex']);
      env = {
        'PATH': '${bin.path}:${Platform.environment['PATH'] ?? ''}',
        'GIT_AUTHOR_NAME': 'T',
        'GIT_AUTHOR_EMAIL': 't@example.com',
        'GIT_COMMITTER_NAME': 'T',
        'GIT_COMMITTER_EMAIL': 't@example.com',
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_SYSTEM': '/dev/null',
        'GIT_CONFIG_NOSYSTEM': '1',
        'STUB_ARGS': '${tmp.path}/args',
        'STUB_STDIN': '${tmp.path}/stdin',
      };
      Directory('$repo/.codex').createSync(recursive: true);
      File(
        '$repo/.codex/config.toml',
      ).writeAsStringSync('review_model = "stub-model"\n');
      File('$repo/a.txt').writeAsStringSync('base\n');
      git(['init', '-q', '-b', 'main']);
      git(['add', '-A']);
      git(['commit', '-qm', 'base']);
      git(['branch', 'base-ref']);
      File('$repo/b.txt').writeAsStringSync('head\n');
      git(['add', '-A']);
      git(['commit', '-qm', 'head']);
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('clean tree: exit 0 and the printed review file exists', () {
      final r = run('base-ref');
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(File((r.stdout as String).trim()).existsSync(), isTrue);
      final args = reviewerArgs();
      expect(args[args.indexOf('--base') + 1], git(['rev-parse', 'base-ref']));
    });

    test('modified tracked file: exit 3, uncommitted', () {
      File('$repo/a.txt').writeAsStringSync('dirty\n');
      final r = run('base-ref');
      expect(r.exitCode, 3);
      expect(r.stderr, contains('uncommitted'));
    });

    test('untracked file: exit 3, uncommitted', () {
      File('$repo/new.txt').writeAsStringSync('new\n');
      final r = run('base-ref');
      expect(r.exitCode, 3);
      expect(r.stderr, contains('uncommitted'));
    });

    test('missing base ref: exit 2 before reviewer login', () {
      final r = run('no-such-ref');
      expect(r.exitCode, 2);
      expect(r.stderr, contains('does not resolve to a commit'));
      expect(File('${tmp.path}/args').existsSync(), isFalse);
    });

    for (final args in <List<String>>[
      [],
      ['--base'],
      ['--base', '--structured'],
      ['--base', ''],
    ]) {
      test('missing base argument $args: exit 2 without reviewer', () {
        final r = runArgs(args);
        expect(r.exitCode, 2, reason: '${r.stderr}');
        expect(r.stderr, contains('usage:'));
        expect(File('${tmp.path}/args').existsSync(), isFalse);
      });
    }

    for (final base in ['HEAD:a.txt', 'HEAD^{tree}']) {
      test('non-commit base $base: exit 2 without reviewer', () {
        final r = run(base);
        expect(r.exitCode, 2);
        expect(r.stderr, contains('does not resolve to a commit'));
        expect(File('${tmp.path}/args').existsSync(), isFalse);
      });
    }

    test('main at HEAD: scope error, not a reviewer failure', () {
      final r = runArgs(
        ['--base', 'main'],
        overrides: {'STUB_LOGIN_EXIT': '1'},
      );
      expect(r.exitCode, 2);
      expect(r.stderr, contains('no changes'));
      expect(r.stderr, contains('not a review waiver'));
      expect(File('${tmp.path}/args').existsSync(), isFalse);
    });

    test('unrelated commit: exit 2 without reviewer', () {
      final tree = git(['rev-parse', 'HEAD^{tree}']);
      final unrelated = git(['commit-tree', tree, '-m', 'unrelated root']);
      final r = run(unrelated);
      expect(r.exitCode, 2);
      expect(r.stderr, contains('no common ancestor'));
      expect(File('${tmp.path}/args').existsSync(), isFalse);
    });

    test('base ahead of HEAD: exit 2 without reviewer', () {
      final tree = git(['rev-parse', 'HEAD^{tree}']);
      final future = git(['commit-tree', tree, '-p', 'HEAD', '-m', 'future']);
      final r = run(future);
      expect(r.exitCode, 2);
      expect(r.stderr, contains('no changes'));
      expect(File('${tmp.path}/args').existsSync(), isFalse);
    });

    test('fully reverted task: empty net diff is not reviewed', () {
      git(['revert', '--no-edit', 'HEAD']);
      final r = run('base-ref');
      expect(r.exitCode, 2);
      expect(r.stderr, contains('no changes'));
      expect(File('${tmp.path}/args').existsSync(), isFalse);
    });

    test('annotated commit tag resolves to the saved SHA', () {
      git(['tag', '-a', 'task-start', 'base-ref', '-m', 'task start']);
      final r = run('task-start');
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final args = reviewerArgs();
      expect(args[args.indexOf('--base') + 1], git(['rev-parse', 'base-ref']));
    });

    for (final structured in [false, true]) {
      test('saved base covers every task commit (structured=$structured)', () {
        final base = git(['rev-parse', 'base-ref']);
        File('$repo/c.txt').writeAsStringSync('second task change\n');
        git(['add', '-A']);
        git(['commit', '-qm', 'second task change']);
        final r = runArgs(['--base', base, if (structured) '--structured']);
        expect(r.exitCode, 0, reason: '${r.stderr}');
        if (structured) {
          final diff = File('${tmp.path}/stdin').readAsStringSync();
          expect(diff, contains('diff --git a/b.txt b/b.txt'));
          expect(diff, contains('diff --git a/c.txt b/c.txt'));
          expect(reviewerArgs().last, contains('against $base'));
        } else {
          final args = reviewerArgs();
          expect(args[args.indexOf('--base') + 1], base);
        }
      });
    }

    for (final structured in [false, true]) {
      test('diverged base uses merge-base (structured=$structured)', () {
        final base = git(['rev-parse', 'base-ref']);
        final tree = git(['rev-parse', 'base-ref^{tree}']);
        final side = git(['commit-tree', tree, '-p', base, '-m', 'side']);
        git(['update-ref', 'refs/heads/side', side]);
        final r = runArgs(['--base', 'side', if (structured) '--structured']);
        expect(r.exitCode, 0, reason: '${r.stderr}');
        final args = reviewerArgs();
        if (structured) {
          expect(args.last, contains('against $base'));
          expect(
            File('${tmp.path}/stdin').readAsStringSync(),
            contains('diff --git a/b.txt b/b.txt'),
          );
        } else {
          expect(args[args.indexOf('--base') + 1], base);
        }
      });
    }

    test('valid scope and unavailable login remain an exit 3 failure', () {
      final r = runArgs(
        ['--base', 'base-ref'],
        overrides: {'STUB_LOGIN_EXIT': '1'},
      );
      expect(r.exitCode, 3);
      expect(r.stderr, contains('not logged in'));
      expect(reviewerArgs(), ['login', 'status']);
    });

    for (final structured in [false, true]) {
      test('moving base ref keeps resolved scope (structured=$structured)', () {
        final base = git(['rev-parse', 'base-ref']);
        final r = runArgs(
          ['--base', 'base-ref', if (structured) '--structured'],
          overrides: {'STUB_MOVE_REF': 'refs/heads/base-ref'},
        );
        expect(r.exitCode, 0, reason: '${r.stderr}');
        expect(git(['rev-parse', 'base-ref']), git(['rev-parse', 'HEAD']));
        final args = reviewerArgs();
        if (structured) {
          expect(args.last, contains('against $base'));
          expect(
            File('${tmp.path}/stdin').readAsStringSync(),
            contains('diff --git a/b.txt b/b.txt'),
          );
        } else {
          expect(args[args.indexOf('--base') + 1], base);
        }
      });
    }
  });

  group('adversarial harness', () {
    test('test-breaker subagent is read-only and uses a fixed model', () {
      final lines = File('.claude/agents/test-breaker.md').readAsLinesSync();
      final front = lines.sublist(1, lines.indexOf('---', 1)).join('\n');
      expect(front, contains('name: test-breaker'));
      expect(
        RegExp(
          r'^tools:\s*Read,\s*Grep,\s*Glob\s*$',
          multiLine: true,
        ).hasMatch(front),
        isTrue,
        reason: 'test-breaker must not get Edit/Write/Bash',
      );
      expect(front, contains('model: sonnet'));
    });

    test('adversarial-tests skill declares its frontmatter', () {
      final lines = File(
        '.claude/skills/adversarial-tests/SKILL.md',
      ).readAsLinesSync();
      final front = lines.sublist(1, lines.indexOf('---', 1)).join('\n');
      expect(
        front,
        allOf(contains('name: adversarial-tests'), contains('description:')),
      );
    });
  });
}
