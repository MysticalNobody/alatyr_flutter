import 'dart:io';
import 'src/checks_workspace.dart';

void main(List<String> args) {
  final root = Directory.current.path;
  if (args.contains('--codegen')) {
    buildCodegenPlan(root).forEach(stdout.writeln);
    return;
  }
  buildChecksPlan(root).map(formatChecksPlanLine).forEach(stdout.writeln);
}
