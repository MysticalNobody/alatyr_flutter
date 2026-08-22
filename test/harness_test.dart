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
}
