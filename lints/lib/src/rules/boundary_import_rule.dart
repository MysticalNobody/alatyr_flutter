import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../graph/boundary_checker.dart';
import '../graph/graph_loader.dart';
import '../graph/path_resolver.dart';

/// Flags imports that cross the architecture boundaries declared in
/// `docs/reference/package_graph.yaml` (for example, a feature's `_impl`
/// package importing a sibling feature's `_impl` package directly instead
/// of going through its `_api` package).
class BoundaryImportRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'alatyr_boundary_import',
    'Architecture boundary violation: {0}',
    severity: DiagnosticSeverity.WARNING,
  );

  BoundaryImportRule()
    : super(
        name: 'alatyr_boundary_import',
        description:
            'Flags imports that cross a declared architecture boundary.',
      );

  @override
  DiagnosticCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry.addImportDirective(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this._rule, this._context);

  final BoundaryImportRule _rule;
  final RuleContext _context;

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri == null) return;

    final graph = GraphLoader.instance.graphFor(
      _context.definingUnit.file.path,
    );
    if (graph == null) return;

    final fromKey = graphKeyForPath(
      filePath: _context.definingUnit.file.path,
      graph: graph,
    );
    if (fromKey == null) return;

    final importedPackage = packageNameFromUri(uri);
    if (importedPackage == null) return;

    final violation = boundaryViolation(
      fromKey: fromKey,
      importedPackage: importedPackage,
      graph: graph,
    );
    if (violation == null) return;

    _rule.reportAtNode(node, arguments: [violation]);
  }
}
