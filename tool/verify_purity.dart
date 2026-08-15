import 'dart:io';
import 'src/graph.dart';
import 'src/purity_checker.dart';

const String _graphPath = 'docs/reference/package_graph.yaml';

Future<void> main() async {
  final graph = loadPackageGraph(
    File(_graphPath).readAsStringSync(),
    sourcePath: _graphPath,
  );

  final result = await _runPubDeps();
  if (result.exitCode != 0) {
    stderr.writeln('dart pub deps --json failed (exit ${result.exitCode}):');
    stderr.write(result.stderr);
    exitCode = 1;
    return;
  }

  final violations = purityViolations(
    pubDepsJson: result.stdout as String,
    purePackages: graph.pureDartPackages,
  );

  if (violations.isEmpty) {
    stdout.writeln('Transitive purity: OK');
    return;
  }
  violations.forEach(stderr.writeln);
  exitCode = 1;
}

/// Runs `dart pub deps --json` in the current directory. Fvm-aware, mirroring
/// tool/common.sh's fvm-first philosophy: try `fvm dart` first, and only
/// fall back to plain `dart` when the `fvm` executable itself can't be
/// found (ProcessException) - a resolved-but-failing `fvm dart` run is a
/// real error and must NOT be papered over by silently retrying with the
/// system `dart`, which could resolve a different SDK/workspace.
Future<ProcessResult> _runPubDeps() async {
  const args = ['pub', 'deps', '--json'];
  try {
    return await Process.run('fvm', ['dart', ...args]);
  } on ProcessException {
    return Process.run('dart', args);
  }
}
