import 'dart:convert';
import 'dart:io';

/// stdin: `xcrun simctl list runtimes -j`; argv[0]: iOS major version.
/// Prints the identifier of the newest available runtime of that major,
/// exit 1 when none is installed. Logic lives in [pickRuntime] so it is
/// unit-tested with fixture JSON (test/e2e_pick_test.dart).
Future<void> main(List<String> args) async {
  final json = await utf8.decoder.bind(stdin).join();
  final id = pickRuntime(json, major: int.parse(args.single));
  if (id == null) {
    exitCode = 1;
    return;
  }
  stdout.write(id);
}

String? pickRuntime(String simctlJson, {required int major}) {
  final json = jsonDecode(simctlJson) as Map<String, dynamic>;
  final runtimes = (json['runtimes'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final candidates =
      runtimes
          .where((r) => r['platform'] == 'iOS' && r['isAvailable'] == true)
          .where((r) {
            final version = r['version'] as String;
            return int.tryParse(version.split('.').first) == major;
          })
          .toList()
        ..sort(
          (a, b) => _compare(a['version'] as String, b['version'] as String),
        );
  if (candidates.isEmpty) {
    return null;
  }
  return candidates.last['identifier'] as String;
}

int _compare(String a, String b) {
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    if (pa[i] != pb[i]) {
      return pa[i].compareTo(pb[i]);
    }
  }
  return pa.length.compareTo(pb.length);
}
