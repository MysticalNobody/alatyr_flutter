import 'dart:io';
import 'src/import_validator.dart';

void main() {
  final violations = validateImports(rootDir: Directory.current.path);
  if (violations.isEmpty) {
    stdout.writeln('Architecture imports: OK');
    return;
  }
  violations.forEach(stderr.writeln);
  exitCode = 1;
}
