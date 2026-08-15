import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Flags a conditional (ternary) expression nested directly inside the
/// `then` or `else` branch of another conditional expression. No
/// test-directory exemption: nested ternaries are equally unreadable in
/// test code.
class NoNestedTernaryRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'alatyr_no_nested_ternary',
    'Nested ternary. Use a switch expression, if/else, or extract a '
        'method.',
    severity: DiagnosticSeverity.WARNING,
  );

  NoNestedTernaryRule()
    : super(
        name: 'alatyr_no_nested_ternary',
        description:
            'Flags a ternary expression nested inside another ternary.',
      );

  @override
  DiagnosticCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry.addConditionalExpression(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this._rule);

  final NoNestedTernaryRule _rule;

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    final parent = node.parent;
    if (parent is! ConditionalExpression) return;
    final isBranchOfParent =
        identical(parent.thenExpression, node) ||
        identical(parent.elseExpression, node);
    if (!isBranchOfParent) return;
    _rule.reportAtNode(node);
  }
}
