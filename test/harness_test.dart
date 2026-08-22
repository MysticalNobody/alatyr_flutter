import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// The harness's own invariants (spec section 4): the contract stays under
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
    expect(rules.map((f) => f.uri.pathSegments.last).toSet(), {
      'testing.md',
      'widgets.md',
      'codegen.md',
    });
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

    test('.codex/hooks.json wires the same guard script via the git root', () {
      final hooks =
          jsonDecode(File('.codex/hooks.json').readAsStringSync())
              as Map<String, dynamic>;
      final pre =
          ((hooks['hooks'] as Map<String, dynamic>)['PreToolUse']
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(pre.single['matcher'], 'Edit|Write');
      final command =
          ((pre.single['hooks'] as List<dynamic>).single
                  as Map<String, dynamic>)['command']
              as String;
      expect(command, contains('git rev-parse --show-toplevel'));
      expect(command, contains('tool/hooks/guard_generated.sh'));
    });
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
        expect(config, contains('review_model = "gpt-5.6-sol"'));
        // The script reads the same pin, so the two cannot drift.
        final script = File(
          '.claude/skills/cross-review/codex_review.sh',
        ).readAsStringSync();
        expect(script, contains('review_model'));
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
