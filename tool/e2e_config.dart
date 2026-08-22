import 'dart:io';

import 'src/e2e_config.dart';

/// Prints tool/e2e.yaml as shell-safe KEY=value lines (quoted with single
/// quotes so `eval` keeps spaces such as "iPhone 16").
void main() {
  final file = File(e2eConfigPath);
  if (!file.existsSync()) {
    stderr.writeln('$e2eConfigPath is missing');
    exitCode = 2;
    return;
  }
  try {
    final config = loadE2eConfig(
      file.readAsStringSync(),
      sourcePath: e2eConfigPath,
    );
    for (final line in envLines(config)) {
      final i = line.indexOf('=');
      stdout.writeln("${line.substring(0, i)}='${line.substring(i + 1)}'");
    }
  } on E2eConfigException catch (e) {
    stderr.writeln(e.message);
    exitCode = 2;
  }
}
