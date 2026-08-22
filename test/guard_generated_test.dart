import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Drives the hook script with the payload shapes both agents really send
/// (captured in the M4 research pass) and checks the exit-code contract:
/// 2 = block, 0 = allow, unparsable = allow (the gate is the backstop).
Future<ProcessResult> runGuard(String stdin) async {
  final process = await Process.start('bash', [
    'tool/hooks/guard_generated.sh',
  ]);
  process.stdin.write(stdin);
  await process.stdin.close();
  final out = await process.stdout.transform(utf8.decoder).join();
  final err = await process.stderr.transform(utf8.decoder).join();
  return ProcessResult(process.pid, await process.exitCode, out, err);
}

String claudePayload(String tool, String filePath) => jsonEncode({
  'session_id': 'abc',
  'transcript_path': '/tmp/t.jsonl',
  'cwd': '/repo',
  'hook_event_name': 'PreToolUse',
  'tool_name': tool,
  'tool_input': tool == 'Write'
      ? {'file_path': filePath, 'content': 'x'}
      : {'file_path': filePath, 'old_string': 'a', 'new_string': 'b'},
});

String codexPayload(String patch) => jsonEncode({
  'session_id': '01a0',
  'turn_id': '01a0',
  'transcript_path': null,
  'cwd': '/repo',
  'hook_event_name': 'PreToolUse',
  'model': 'gpt-5.6-sol',
  'permission_mode': 'default',
  'tool_name': 'apply_patch',
  'tool_input': {'command': patch},
  'tool_use_id': 'exec-1',
});

void main() {
  test(
    'Claude Write on a .g.dart file is blocked with the codegen hint',
    () async {
      final r = await runGuard(
        claudePayload(
          'Write',
          '/repo/packages/data_local/lib/src/app_database.g.dart',
        ),
      );
      expect(r.exitCode, 2);
      expect(r.stderr, contains('tool/codegen.sh'));
    },
  );

  test(
    'Claude Edit on .freezed.dart and .drift.dart files is blocked',
    () async {
      expect(
        (await runGuard(
          claudePayload('Edit', '/r/lib/s.freezed.dart'),
        )).exitCode,
        2,
      );
      expect(
        (await runGuard(claudePayload('Edit', '/r/lib/s.drift.dart'))).exitCode,
        2,
      );
    },
  );

  test('Claude Edit on a hand-written Dart file is allowed', () async {
    final r = await runGuard(
      claudePayload(
        'Edit',
        '/repo/packages/data_local/lib/src/key_value_dao.dart',
      ),
    );
    expect(r.exitCode, 0);
    expect(r.stderr, isEmpty);
  });

  test(
    'a file whose name merely contains "g.dart" is allowed (suffix match only)',
    () async {
      expect(
        (await runGuard(claudePayload('Write', '/r/lib/config.dart'))).exitCode,
        0,
      );
      expect(
        (await runGuard(claudePayload('Write', '/r/lib/big.dart'))).exitCode,
        0,
      );
    },
  );

  test(
    'Codex apply_patch touching a generated file among others is blocked',
    () async {
      const patch =
          '*** Begin Patch\n*** Update File: packages/data_local/lib/src/key_value_dao.dart\n@@\n-a\n+b\n*** Add File: packages/data_local/lib/src/key_value_dao.g.dart\n+hello\n*** End Patch';
      final r = await runGuard(codexPayload(patch));
      expect(r.exitCode, 2);
      expect(r.stderr, contains('key_value_dao.g.dart'));
    },
  );

  test(
    'Codex apply_patch moving a file onto a generated name is blocked',
    () async {
      const patch =
          '*** Begin Patch\n*** Update File: lib/a.dart\n*** Move to: lib/a.freezed.dart\n@@\n-a\n+b\n*** End Patch';
      expect((await runGuard(codexPayload(patch))).exitCode, 2);
    },
  );

  test('Codex apply_patch deleting a generated file is blocked', () async {
    const patch =
        '*** Begin Patch\n*** Delete File: lib/a.g.dart\n*** End Patch';
    expect((await runGuard(codexPayload(patch))).exitCode, 2);
  });

  test('Codex apply_patch on hand-written files only is allowed', () async {
    const patch =
        '*** Begin Patch\n*** Add File: demo.txt\n+hello\n*** Update File: lib/main.dart\n@@\n-a\n+b\n*** End Patch';
    expect((await runGuard(codexPayload(patch))).exitCode, 0);
  });

  test(
    'a generated-file name mentioned only inside patch content does not block',
    () async {
      const patch =
          '*** Begin Patch\n*** Update File: docs/x.md\n@@\n-a\n+see app_database.g.dart for the schema\n*** End Patch';
      expect((await runGuard(codexPayload(patch))).exitCode, 0);
    },
  );

  test(
    'a Claude Write whose CONTENT quotes Codex patch headers or a file_path key is allowed',
    () async {
      final payload = jsonEncode({
        'hook_event_name': 'PreToolUse',
        'tool_name': 'Write',
        'tool_input': {
          'file_path': '/repo/docs/workflow/getting-started.md',
          'content':
              'Example payload:\n*** Add File: demo.g.dart\n{"file_path":"x.freezed.dart"}\n',
        },
      });
      final r = await runGuard(payload);
      expect(r.exitCode, 0, reason: r.stderr as String);
    },
  );

  test(
    'unparsable or empty input is allowed (fail open; the gate is the backstop)',
    () async {
      expect((await runGuard('')).exitCode, 0);
      expect((await runGuard('{}')).exitCode, 0);
      expect((await runGuard('not json at all')).exitCode, 0);
    },
  );

  group('format_dart.sh (PostToolUse)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('format_hook'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<int> runFormat(String filePath) async {
      final process = await Process.start('bash', [
        'tool/hooks/format_dart.sh',
      ]);
      process.stdin.write(
        jsonEncode({
          'tool_name': 'Write',
          'tool_input': {'file_path': filePath, 'content': ''},
        }),
      );
      await process.stdin.close();
      await process.stdout.drain<void>();
      await process.stderr.drain<void>();
      return process.exitCode;
    }

    test('formats the edited Dart file and exits 0', () async {
      final file = File('${tmp.path}/a.dart')
        ..writeAsStringSync('void main(){print( 1 );}\n');
      expect(await runFormat(file.path), 0);
      expect(file.readAsStringSync(), 'void main() {\n  print(1);\n}\n');
    });

    test(
      'leaves generated files and non-Dart files alone, still exit 0',
      () async {
        final gen = File('${tmp.path}/a.g.dart')
          ..writeAsStringSync('void main(){print( 1 );}\n');
        expect(await runFormat(gen.path), 0);
        expect(gen.readAsStringSync(), 'void main(){print( 1 );}\n');
        expect(await runFormat('${tmp.path}/missing.dart'), 0);
        final notes = File('${tmp.path}/notes.md')
          ..writeAsStringSync('void main(){print( 1 );}\n');
        expect(await runFormat(notes.path), 0);
        expect(notes.readAsStringSync(), 'void main(){print( 1 );}\n');
      },
    );

    test(
      'a Codex apply_patch tool_response formats the added file and leaves '
      'the generated one alone (absolute temp paths keep the case hermetic; '
      'a real payload\'s relative paths resolve against the git root)',
      () async {
        final dirty = File('${tmp.path}/a.dart')
          ..writeAsStringSync('void main(){print( 1 );}\n');
        final generated = File('${tmp.path}/b.g.dart')
          ..writeAsStringSync('void main(){print( 1 );}\n');
        final payload = jsonEncode({
          'tool_name': 'apply_patch',
          'tool_input': {'command': '*** Begin Patch\n*** End Patch'},
          'tool_response':
              'Exit code: 0\nWall time: 0.1 seconds\nOutput:\nSuccess. '
              'Updated the following files:\n'
              'A ${dirty.path}\n'
              'M ${generated.path}\n',
        });
        final process = await Process.start('bash', [
          'tool/hooks/format_dart.sh',
        ]);
        process.stdin.write(payload);
        await process.stdin.close();
        await process.stdout.drain<void>();
        await process.stderr.drain<void>();
        expect(await process.exitCode, 0);
        expect(dirty.readAsStringSync(), 'void main() {\n  print(1);\n}\n');
        expect(generated.readAsStringSync(), 'void main(){print( 1 );}\n');
      },
    );
  });
}
