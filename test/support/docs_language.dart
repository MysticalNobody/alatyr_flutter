import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

final _cyrillic = RegExp(r'[\u0400-\u04FF]');

bool _isCanonicalDocumentation(String path) =>
    const {
      'README.md',
      'AGENTS.md',
      'CLAUDE.md',
      'app/README.md',
    }.contains(path) ||
    (path.startsWith('docs/') &&
        path.endsWith('.md') &&
        !path.endsWith('.ru.md') &&
        !path.startsWith('docs/superpowers/'));

/// Reports Cyrillic in tracked and new, non-ignored canonical documentation.
List<String> findCyrillicDocumentation(Directory root) {
  Iterable<String> lsFiles(List<String> args) {
    final result = Process.runSync('git', [
      'ls-files',
      ...args,
    ], workingDirectory: root.path);
    if (result.exitCode != 0) {
      throw StateError('Cannot enumerate documentation: ${result.stderr}');
    }
    return (result.stdout as String)
        .split('\u0000')
        .where((path) => path.isNotEmpty);
  }

  final candidates = {
    ...lsFiles(['-z']),
    ...lsFiles(['--others', '--exclude-standard', '-z']),
  };
  final hits = <String>[];
  for (final path in candidates) {
    if (!_isCanonicalDocumentation(path)) continue;
    final file = File(p.join(root.path, path));
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    if (bytes.take(1024).contains(0)) continue;
    if (_cyrillic.hasMatch(utf8.decode(bytes, allowMalformed: true))) {
      hits.add(path);
    }
  }
  return hits;
}
