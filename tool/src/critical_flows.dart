import 'dart:io';

import 'package:path/path.dart' as p;

/// One row of docs/reference/critical_flows.md: flow name -> patrol test.
final class CriticalFlow {
  const CriticalFlow({
    required this.name,
    required this.testPath,
    required this.line,
  });
  final String name;
  final String testPath;

  /// 1-based line in the registry, for `path:line:` style messages.
  final int line;
}

const String criticalFlowsRegistryPath = 'docs/reference/critical_flows.md';

final _separatorCell = RegExp(r'^:?-+:?$');

/// Parses every markdown table row of [markdown] (lines whose first
/// non-blank character is `|`). The header row (first cell `Flow`) and
/// separator rows (`|---|---|`) are skipped; every other row must carry
/// exactly two cells. Surrounding backticks on the `Test` cell are
/// tolerated so the path may be written as code. Structural problems go to
/// [problems] (`N: ...`, N = 1-based line) so every malformed row is listed.
List<CriticalFlow> parseCriticalFlows(
  String markdown, {
  required List<String> problems,
}) {
  final flows = <CriticalFlow>[];
  final lines = markdown.split('\n');
  var sawHeader = false;
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    if (!raw.trimLeft().startsWith('|')) continue;
    final cells = raw
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (cells.isEmpty) continue;
    if (cells.first == 'Flow') {
      sawHeader = true;
      continue;
    }
    if (cells.every(_separatorCell.hasMatch)) continue;
    if (cells.length != 2) {
      problems.add(
        '${i + 1}: expected 2 cells (Flow | Test), got ${cells.length}',
      );
      continue;
    }
    final testPath = _stripBackticks(cells[1]);
    if (testPath.isEmpty) {
      problems.add('${i + 1}: empty Test cell');
      continue;
    }
    flows.add(CriticalFlow(name: cells[0], testPath: testPath, line: i + 1));
  }
  if (!sawHeader) problems.add('1: no `| Flow | Test |` header row found');
  return flows;
}

String _stripBackticks(String cell) =>
    cell.length >= 2 && cell.startsWith('`') && cell.endsWith('`')
    ? cell.substring(1, cell.length - 1)
    : cell;

/// The gate's registry check: every `Test` path must be a repo-relative
/// path to an existing `*_test.dart` file. Returns violations
/// (`registry:line: message`), empty = OK.
List<String> validateCriticalFlows({
  required String rootDir,
  String registryPath = criticalFlowsRegistryPath,
}) {
  final file = File(p.join(rootDir, registryPath));
  if (!file.existsSync()) return ['$registryPath: registry file is missing'];
  final problems = <String>[];
  final flows = parseCriticalFlows(file.readAsStringSync(), problems: problems);
  final violations = [for (final m in problems) '$registryPath:$m'];
  for (final flow in flows) {
    final path = flow.testPath;
    final where = '$registryPath:${flow.line}';
    if (p.isAbsolute(path) || path.contains('..')) {
      violations.add('$where: "$path" must be a repo-relative path');
      continue;
    }
    if (!path.endsWith('_test.dart')) {
      violations.add('$where: "$path" is not a *_test.dart file');
    }
    // docs/reference/critical_flows.md: critical flows are patrol tests under
    // app/integration_test/ - a unit test cannot stand in for one.
    if (!path.startsWith('app/integration_test/')) {
      violations.add('$where: "$path" is not under app/integration_test/');
    }
    if (!File(p.join(rootDir, path)).existsSync()) {
      violations.add(
        '$where: flow "${flow.name}" points to a missing test: $path',
      );
    }
  }
  // The reverse direction: an integration test the registry does not name
  // is a critical flow invisible to the test plan - the registry would
  // read as complete while a whole flow ships unregistered.
  final integrationDir = Directory(p.join(rootDir, 'app', 'integration_test'));
  if (integrationDir.existsSync()) {
    final registered = {for (final f in flows) f.testPath};
    final tests =
        integrationDir
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .map((f) => p.relative(f.path, from: rootDir))
            .where((rel) => rel.endsWith('_test.dart'))
            .toList()
          ..sort();
    for (final rel in tests) {
      if (!registered.contains(rel)) {
        violations.add(
          '$rel: not registered in $registryPath - every '
          'app/integration_test/*_test.dart must be named by a registry row',
        );
      }
    }
  }
  return violations;
}
