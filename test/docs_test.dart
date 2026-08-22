import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The docs set of spec section 13, kept honest by machine: every file
/// exists, every relative link resolves, and nothing shipped is in
/// Russian (twins are gitignored).
const requiredDocs = [
  'docs/README.md',
  'docs/architecture/01-overview.md',
  'docs/architecture/02-package-graph.md',
  'docs/architecture/03-feature-contract.md',
  'docs/architecture/04-composition.md',
  'docs/architecture/05-error-handling.md',
  'docs/architecture/06-security.md',
  'docs/adr/README.md',
  'docs/adr/template.md',
  'docs/adr/0001-package-boundaries.md',
  'docs/adr/0002-manual-di.md',
  'docs/adr/0003-test-strategy.md',
  'docs/adr/0004-single-gate.md',
  'docs/adr/0005-cross-review-protocol.md',
  'docs/adr/0006-working-placeholder-instantiation.md',
  'docs/testing/strategy.md',
  'docs/testing/widget-test-guardrails.md',
  'docs/workflow/getting-started.md',
  'docs/workflow/feature-workflow.md',
  'docs/workflow/maintenance.md',
  'docs/workflow/modules.md',
  'docs/reference/critical_flows.md',
  'docs/reference/ci_contract.md',
  'docs/reference/feature_package_skeletons.md',
  'README.md',
];

final _link = RegExp(r'\[[^\]]*\]\(([^)\s#]+)(#[^)]*)?\)');
// Written with escapes on purpose: this file is scanned by its own test.
final _cyrillic = RegExp(r'[\u0400-\u04FF]');
final _fencedBlock = RegExp(r'```[\s\S]*?```');
final _inlineCode = RegExp(r'`[^`\n]*`');

/// Shipped markdown: the top-level contracts plus docs/, minus the working
/// documents under docs/superpowers/ (deleted by init) and Russian twins.
Iterable<File> _markdownFiles() sync* {
  for (final top in ['README.md', 'AGENTS.md', 'CLAUDE.md']) {
    final f = File(top);
    if (f.existsSync()) yield f;
  }
  yield* Directory('docs')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.md') &&
            !f.path.endsWith('.ru.md') &&
            !p.split(f.path).contains('superpowers'),
      );
}

/// Markdown with code removed, so examples inside fences/spans are not
/// mistaken for links.
String _prose(File file) => file
    .readAsStringSync()
    .replaceAll(_fencedBlock, '')
    .replaceAll(_inlineCode, '');

void main() {
  test('every documented file exists', () {
    final missing = requiredDocs.where((d) => !File(d).existsSync()).toList();
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('every relative markdown link resolves', () {
    final broken = <String>[];
    for (final file in _markdownFiles()) {
      for (final m in _link.allMatches(_prose(file))) {
        final target = m.group(1)!;
        if (target.startsWith('http://') ||
            target.startsWith('https://') ||
            target.startsWith('mailto:')) {
          continue;
        }
        if (target.contains('<') || target.contains('>')) {
          continue; // placeholder in prose
        }
        final resolved = p.normalize(p.join(p.dirname(file.path), target));
        if (!File(resolved).existsSync() && !Directory(resolved).existsSync()) {
          broken.add('${file.path}: $target');
        }
      }
    }
    expect(broken, isEmpty, reason: broken.join('\n'));
  });

  test('architecture docs stay at 1-2 pages and ADRs stay short', () {
    for (final doc in requiredDocs.where(
      (d) => d.startsWith('docs/architecture/'),
    )) {
      expect(
        File(doc).readAsLinesSync().length,
        lessThanOrEqualTo(120),
        reason: doc,
      );
    }
    for (final adr in requiredDocs.where(
      (d) => RegExp(r'docs/adr/\d{4}-').hasMatch(d),
    )) {
      expect(
        File(adr).readAsLinesSync().length,
        lessThanOrEqualTo(60),
        reason: adr,
      );
    }
  });

  test(
    'critical_flows.md has the registry table shape the gate will parse',
    () {
      final lines = File('docs/reference/critical_flows.md').readAsLinesSync();
      expect(lines, contains('| Flow | Test |'));
      final rows = lines.where((l) => l.trimLeft().startsWith('|'));
      for (final row in rows) {
        final cells = row
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cells.isEmpty || cells.first == 'Flow') {
          continue; // header
        }
        if (cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c))) {
          continue; // separator
        }
        expect(cells, hasLength(2), reason: row);
        expect(
          File(cells[1]).existsSync(),
          isTrue,
          reason: 'registry entry points to a missing test: ${cells[1]}',
        );
      }
    },
  );

  test('no shipped (tracked or untracked) file contains Cyrillic', () {
    Iterable<String> lsFiles(List<String> args) =>
        (Process.runSync('git', ['ls-files', ...args]).stdout as String)
            .split('\u0000')
            .where((s) => s.isNotEmpty);
    // Untracked-but-not-ignored files are scanned too: a brand-new file with
    // Russian text must fail the local gate, not only CI after it lands.
    // Gitignored paths (the `*.ru.md` twins, CLAUDE.local.md) stay excluded.
    final candidates = [
      ...lsFiles(['-z']),
      ...lsFiles(['--others', '--exclude-standard', '-z']),
    ];
    final hits = <String>[];
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      // Skip binaries: a NUL byte in the first 1 KB is good enough here.
      if (bytes.take(1024).contains(0)) continue;
      final text = utf8.decode(bytes, allowMalformed: true);
      if (_cyrillic.hasMatch(text)) hits.add(path);
    }
    expect(
      hits,
      isEmpty,
      reason: 'Russian text in shipped files:\n${hits.join('\n')}',
    );
  });
}
