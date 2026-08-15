import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../graph/boundary_checker.dart';
import '../graph/graph_loader.dart';
import '../graph/path_resolver.dart';

/// Flags Flutter/UI imports (`package:flutter*` or `dart:ui`) from packages
/// declared `pure_dart_packages` in `docs/reference/package_graph.yaml` —
/// core packages that must stay testable without the Flutter engine.
class PureCoreRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'alatyr_pure_core',
    'Core purity violation: {0}',
    severity: DiagnosticSeverity.WARNING,
  );

  PureCoreRule()
    : super(
        name: 'alatyr_pure_core',
        description:
            'Flags Flutter/UI imports from packages declared pure Dart.',
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

  final PureCoreRule _rule;
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

    final violation = pureCoreViolation(
      fromKey: fromKey,
      importUri: uri,
      graph: graph,
    );
    if (violation == null) return;

    _rule.reportAtNode(node, arguments: [violation]);
  }
}
