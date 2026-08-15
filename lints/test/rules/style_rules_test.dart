import 'package:alatyr_lints/src/rules/no_nested_ternary_rule.dart';
import 'package:alatyr_lints/src/rules/no_widget_returning_function_rule.dart';
import 'package:alatyr_lints/src/rules/one_widget_per_file_rule.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(OneWidgetPerFileRuleTest);
    defineReflectiveTests(NoWidgetReturningFunctionRuleTest);
    defineReflectiveTests(NoNestedTernaryRuleTest);
  });
}

@reflectiveTest
class OneWidgetPerFileRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = OneWidgetPerFileRule();
    super.setUp();
  }

  Future<void> test_twoPublicWidgets_firesOnSecond() async {
    await assertDiagnostics(
      r'''
class StatelessWidget {}
class HomeCard extends StatelessWidget {}
class HomePage extends StatelessWidget {}
''',
      [
        lint(73, 8, messageContainsAll: ['HomeCard', 'HomePage']),
      ],
    );
  }

  Future<void> test_privateSecondWidget_noDiagnostics() async {
    await assertNoDiagnostics(r'''
class StatelessWidget {}
class HomeCard extends StatelessWidget {}
class _HomeCardImpl extends StatelessWidget {}
''');
  }

  Future<void> test_testDirectory_exempt() async {
    final path = '$testPackageRootPath/test/widgets_test.dart';
    newFile(path, r'''
class StatelessWidget {}
class HomeCard extends StatelessWidget {}
class HomePage extends StatelessWidget {}
''');
    await assertNoDiagnosticsInFile(path);
  }
}

@reflectiveTest
class NoWidgetReturningFunctionRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = NoWidgetReturningFunctionRule();
    super.setUp();
  }

  Future<void> test_methodReturningWidget_fires() async {
    await assertDiagnostics(
      r'''
class Widget {}
class Foo {
  Widget buildHeader() => Widget();
}
''',
      [
        lint(37, 11, messageContainsAll: ['buildHeader']),
      ],
    );
  }

  Future<void> test_topLevelFunctionReturningWidget_fires() async {
    await assertDiagnostics(
      r'''
class Widget {}
Widget buildHeader() => Widget();
''',
      [
        lint(23, 11, messageContainsAll: ['buildHeader']),
      ],
    );
  }

  Future<void> test_build_noDiagnostics() async {
    await assertNoDiagnostics(r'''
class Widget {}
class Foo {
  Widget build() => Widget();
}
''');
  }

  Future<void> test_getter_noDiagnostics() async {
    await assertNoDiagnostics(r'''
class Widget {}
class Foo {
  Widget get header => Widget();
}
''');
  }

  Future<void> test_localFunctionReturningWidget_noDiagnostics() async {
    // Only top-level function declarations are in scope; a local function
    // nested inside another function is exempt.
    await assertNoDiagnostics(r'''
class Widget {}
void outer() {
  Widget buildHeader() => Widget();
  buildHeader();
}
''');
  }

  Future<void> test_testDirectory_exempt() async {
    final path = '$testPackageRootPath/test/widget_test.dart';
    newFile(path, r'''
class Widget {}
class Foo {
  Widget buildHeader() => Widget();
}
''');
    await assertNoDiagnosticsInFile(path);
  }
}

@reflectiveTest
class NoNestedTernaryRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = NoNestedTernaryRule();
    super.setUp();
  }

  Future<void> test_nestedInElse_firesOnInner() async {
    await assertDiagnostics(
      r'''
void f(bool a, bool b) {
  final x = a ? 1 : b ? 2 : 3;
}
''',
      [lint(45, 9)],
    );
  }

  Future<void> test_nestedInThen_firesOnInner() async {
    await assertDiagnostics(
      r'''
void f(bool a, bool b) {
  final x = a ? b ? 1 : 2 : 3;
}
''',
      [lint(41, 9)],
    );
  }

  Future<void> test_ternaryInCondition_noDiagnostics() async {
    await assertNoDiagnostics(r'''
void f(bool a, bool b, bool c) {
  final x = (a ? b : c) ? 1 : 2;
}
''');
  }

  Future<void> test_testDirectory_notExempt() async {
    final path = '$testPackageRootPath/test/ternary_test.dart';
    newFile(path, r'''
void f(bool a, bool b) {
  final x = a ? 1 : b ? 2 : 3;
}
''');
    await assertDiagnosticsInFile(path, [lint(45, 9)]);
  }
}
