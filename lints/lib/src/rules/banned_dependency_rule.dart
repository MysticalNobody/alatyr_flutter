import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../graph/boundary_checker.dart';
import '../graph/graph_loader.dart';
import '../graph/package_graph.dart';

/// Flags imports of packages listed under `banned_packages` in
/// `docs/reference/package_graph.yaml`. Unlike the boundary and pure-core
/// rules, this one does not need to resolve which package the importing
/// file belongs to — a banned dependency is banned everywhere.
class BannedDependencyRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'alatyr_banned_dependency',
    'Banned dependency: {0}',
    severity: DiagnosticSeverity.WARNING,
  );

  BannedDependencyRule()
    : super(
        name: 'alatyr_banned_dependency',
        description: 'Flags imports of packages banned without an ADR.',
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

  final BannedDependencyRule _rule;
  final RuleContext _context;

  @override
  void visitImportDirective(ImportDirective node) => _checkDirective(node);

  @override
  void visitExportDirective(ExportDirective node) => _checkDirective(node);

  // Checks the directive's own URI, plus every conditional-import/export
  // branch's URI (`if (...) 'uri'`) — a banned dependency is banned
  // regardless of which branch a given platform ends up selecting.
  void _checkDirective(NamespaceDirective node) {
    final graph = GraphLoader.instance.graphFor(
      _context.definingUnit.file.path,
    );
    if (graph == null) return;

    _checkUri(reportNode: node, uri: node.uri.stringValue, graph: graph);
    for (final configuration in node.configurations) {
      _checkUri(
        reportNode: configuration,
        uri: configuration.uri.stringValue,
        graph: graph,
      );
    }
  }

  void _checkUri({
    required AstNode reportNode,
    required String? uri,
    required PackageGraph graph,
  }) {
    if (uri == null) return;

    final importedPackage = packageNameFromUri(uri);
    if (importedPackage == null) return;

    final violation = bannedViolation(
      importedPackage: importedPackage,
      graph: graph,
    );
    if (violation == null) return;

    _rule.reportAtNode(reportNode, arguments: [violation]);
  }
}
