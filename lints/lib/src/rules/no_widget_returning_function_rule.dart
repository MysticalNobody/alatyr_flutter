import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'style_predicates.dart';

/// Flags methods and top-level functions that return a bare `Widget`
/// instead of a dedicated widget class; `build()` is exempt, since that is
/// exactly how Flutter widgets are meant to produce their subtree. Exempt
/// in test directories.
class NoWidgetReturningFunctionRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'alatyr_no_widget_returning_function',
    "'{0}' returns Widget. Extract a widget class instead (build() is "
        'exempt).',
    severity: DiagnosticSeverity.WARNING,
  );

  NoWidgetReturningFunctionRule()
    : super(
        name: 'alatyr_no_widget_returning_function',
        description:
            'Flags methods/functions that return a bare Widget instead of '
            'a widget class.',
      );

  @override
  DiagnosticCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (context.isInTestDirectory) return;
    final visitor = _Visitor(this);
    registry
      ..addMethodDeclaration(this, visitor)
      ..addFunctionDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this._rule);

  final NoWidgetReturningFunctionRule _rule;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _check(
      name: node.name,
      returnType: node.returnType,
      isAccessor: node.isGetter || node.isSetter,
    );
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // A local (nested) function is also represented as a FunctionDeclaration
    // (wrapped in a FunctionDeclarationStatement), but only top-level
    // functions are in scope for this rule.
    if (node.parent is! CompilationUnit) return;
    _check(
      name: node.name,
      returnType: node.returnType,
      isAccessor: node.isGetter || node.isSetter,
    );
  }

  void _check({
    required Token name,
    required TypeAnnotation? returnType,
    required bool isAccessor,
  }) {
    final returnTypeName = returnType is NamedType
        ? returnType.name.lexeme
        : null;
    if (!isDisallowedWidgetReturn(
      name: name.lexeme,
      returnTypeName: returnTypeName,
      isAccessor: isAccessor,
    )) {
      return;
    }
    _rule.reportAtToken(name, arguments: [name.lexeme]);
  }
}
