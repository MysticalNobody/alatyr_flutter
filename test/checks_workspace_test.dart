import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/src/checks_workspace.dart';

void main() {
  final root = p.join('test', 'fixtures', 'workspaces', 'plan');

  test('plan classifies runner and test presence per member', () {
    final lines = buildChecksPlan(root).map(formatChecksPlanLine).toList();
    expect(lines, [
      'dart\tpackages/pure\ttrue',
      'flutter\tpackages/flutterish\tfalse',
      'dart\tpackages/gen\ttrue',
    ]);
  });

  test('codegen plan lists only build_runner packages', () {
    expect(buildCodegenPlan(root), ['packages/gen']);
  });
}
