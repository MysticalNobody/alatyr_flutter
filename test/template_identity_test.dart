import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Spec section 9: packages/, lints/ and tool/ are product-neutral by
/// construction, so init's identity rewrite never has to touch them - and
/// neither are the agent harness files (AGENTS.md, CLAUDE.md, .claude/,
/// .codex/), which init must leave untouched. This test is what makes
/// "by construction" true. Init deletes this file (it is template-only).
void main() {
  const identityTokens = [
    'alatyr_starter',
    'dev.alatyr',
    'Alatyr Starter',
    'alatyr_workspace',
  ];
  const neutralDirs = ['packages', 'lints', 'tool', '.claude', '.codex'];
  const neutralFiles = ['AGENTS.md', 'CLAUDE.md'];
  const skippedDirNames = {'.dart_tool', 'build'};
  // A developer's local Claude settings are not shipped.
  const skippedFileNames = {'settings.local.json'};

  Iterable<File> neutralTree() sync* {
    for (final dir in neutralDirs) {
      yield* Directory(dir)
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => !p.split(f.path).any(skippedDirNames.contains))
          .where((f) => !skippedFileNames.contains(p.basename(f.path)));
    }
    for (final file in neutralFiles) {
      yield File(file);
    }
  }

  test('product-neutral directories contain no placeholder identity token', () {
    final hits = <String>[];
    var scanned = 0;
    for (final file in neutralTree()) {
      final bytes = file.readAsBytesSync();
      // Skip binaries (NUL in the first 1 KB, as docs_test does) and decode
      // tolerantly so a stray byte in a fixture cannot crash the scan.
      if (bytes.take(1024).contains(0)) continue;
      scanned++;
      final lines = const LineSplitter().convert(
        utf8.decode(bytes, allowMalformed: true),
      );
      for (var i = 0; i < lines.length; i++) {
        for (final token in identityTokens) {
          if (lines[i].contains(token)) {
            hits.add('${file.path}:${i + 1}: $token');
          }
        }
      }
    }
    expect(scanned, greaterThan(50), reason: 'scan must actually walk files');
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
