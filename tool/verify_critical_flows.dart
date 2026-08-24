import 'dart:io';

import 'src/critical_flows.dart';

void main() {
  final violations = validateCriticalFlows(rootDir: Directory.current.path);
  if (violations.isEmpty) {
    stdout.writeln('Critical flows registry: OK');
    return;
  }
  violations.forEach(stderr.writeln);
  exitCode = 1;
}
