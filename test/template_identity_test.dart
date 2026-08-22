import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Spec section 9: packages/, lints/ and tool/ are product-neutral by
/// construction, so init's identity rewrite never has to touch them. This
/// test is what makes "by construction" true.
void main() {
  const identityTokens = [
    'alatyr_starter',
    'dev.alatyr',
    'Alatyr Starter',
    'alatyr_workspace',
  ];
  const neutralDirs = ['packages', 'lints', 'tool'];
  const skippedDirNames = {'.dart_tool', 'build'};

  test('product-neutral directories contain no placeholder identity token', () {
    final hits = <String>[];
    for (final dir in neutralDirs) {
      final files = Directory(dir)
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => !p.split(f.path).any(skippedDirNames.contains));
      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final token in identityTokens) {
            if (lines[i].contains(token)) {
              hits.add('${file.path}:${i + 1}: $token');
            }
          }
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
