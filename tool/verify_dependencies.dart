import 'dart:io';
import 'src/dependency_validator.dart';

void main() {
  final violations = validateDependencies(rootDir: Directory.current.path);
  if (violations.isEmpty) {
    stdout.writeln('Dependency graph: OK');
    return;
  }
  violations.forEach(stderr.writeln);
  exitCode = 1;
}
