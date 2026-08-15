import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/banned_dependency_rule.dart';
import 'src/rules/boundary_import_rule.dart';
import 'src/rules/no_nested_ternary_rule.dart';
import 'src/rules/no_widget_returning_function_rule.dart';
import 'src/rules/one_widget_per_file_rule.dart';
import 'src/rules/pure_core_rule.dart';

final plugin = AlatyrLintsPlugin();

class AlatyrLintsPlugin extends Plugin {
  @override
  String get name => 'alatyr_lints';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(BoundaryImportRule())
      ..registerWarningRule(BannedDependencyRule())
      ..registerWarningRule(PureCoreRule())
      ..registerWarningRule(OneWidgetPerFileRule())
      ..registerWarningRule(NoWidgetReturningFunctionRule())
      ..registerWarningRule(NoNestedTernaryRule());
  }
}
