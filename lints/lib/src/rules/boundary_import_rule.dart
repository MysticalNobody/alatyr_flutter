import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../graph/boundary_checker.dart';
import '../graph/graph_loader.dart';
import '../graph/package_graph.dart';
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
    registry
      ..addImportDirective(this, visitor)
      ..addExportDirective(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this._rule, this._context);

  final BoundaryImportRule _rule;
  final RuleContext _context;

  @override
  void visitImportDirective(ImportDirective node) => _checkDirective(node);

  @override
  void visitExportDirective(ExportDirective node) => _checkDirective(node);

  // Checks the directive's own URI, plus every conditional-import/export
  // branch's URI (`if (...) 'uri'`) — any branch that crosses the boundary
  // is a violation, regardless of which one a given platform selects.
  void _checkDirective(NamespaceDirective node) {
    final graph = GraphLoader.instance.graphFor(
      _context.definingUnit.file.path,
    );
    if (graph == null) return;

    final fromKey = graphKeyForPath(
      filePath: _context.definingUnit.file.path,
      graph: graph,
    );
    if (fromKey == null) return;

    _checkUri(
      reportNode: node,
      uri: node.uri.stringValue,
      fromKey: fromKey,
      graph: graph,
    );
    for (final configuration in node.configurations) {
      _checkUri(
        reportNode: configuration,
        uri: configuration.uri.stringValue,
        fromKey: fromKey,
        graph: graph,
      );
    }
  }

  void _checkUri({
    required AstNode reportNode,
    required String? uri,
    required String fromKey,
    required PackageGraph graph,
  }) {
    if (uri == null) return;

    final importedPackage = packageNameFromUri(uri);
    if (importedPackage == null) return;

    final violation = boundaryViolation(
      fromKey: fromKey,
      importedPackage: importedPackage,
      graph: graph,
    );
    if (violation == null) return;

    _rule.reportAtNode(reportNode, arguments: [violation]);
  }
}
