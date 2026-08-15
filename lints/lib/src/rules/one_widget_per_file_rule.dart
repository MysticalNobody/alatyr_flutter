import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'style_predicates.dart';

/// Flags files that declare more than one public widget class (a top-level
/// class whose superclass is `StatelessWidget` or `StatefulWidget`).
/// Private (`_Foo`) helper widgets are unaffected — split public widgets
/// into their own files instead. Exempt in test directories, where
/// declaring a couple of tiny widget fixtures side by side is normal.
class OneWidgetPerFileRule extends AnalysisRule {
  static const LintCode _code = LintCode(
    'alatyr_one_widget_per_file',
    'File declares more than one public widget class ({0}). Keep one '
        'public widget per file; private (_Foo) helpers are fine.',
    severity: DiagnosticSeverity.WARNING,
  );

  OneWidgetPerFileRule()
    : super(
        name: 'alatyr_one_widget_per_file',
        description:
            'Flags files that declare more than one public widget class.',
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
    registry.addCompilationUnit(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this._rule);

  final OneWidgetPerFileRule _rule;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final widgetClasses = node.declarations
        .whereType<ClassDeclaration>()
        .where(
          (declaration) => isPublicWidgetClass(
            className: declaration.namePart.typeName.lexeme,
            superclassName: declaration.extendsClause?.superclass.name.lexeme,
          ),
        )
        .toList();

    if (widgetClasses.length <= 1) return;

    final allNames = widgetClasses
        .map((declaration) => declaration.namePart.typeName.lexeme)
        .join(', ');

    for (final declaration in widgetClasses.skip(1)) {
      _rule.reportAtToken(declaration.namePart.typeName, arguments: [allNames]);
    }
  }
}
