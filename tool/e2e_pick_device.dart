import 'dart:convert';
import 'dart:io';

/// stdin: `xcrun simctl list devices -j`; argv: simulator name, runtime
/// identifier. Prints `<udid> <state>` (state = Booted | Shutdown | ...)
/// of an available device with that name under that runtime, exit 1 when
/// absent. Logic in [pickDevice] (unit-tested with fixture JSON).
Future<void> main(List<String> args) async {
  final json = await utf8.decoder.bind(stdin).join();
  final found = pickDevice(json, name: args[0], runtime: args[1]);
  if (found == null) {
    exitCode = 1;
    return;
  }
  stdout.write(found);
}

String? pickDevice(
  String simctlJson, {
  required String name,
  required String runtime,
}) {
  final json = jsonDecode(simctlJson) as Map<String, dynamic>;
  final devices =
      (json['devices'] as Map<String, dynamic>)[runtime] as List<dynamic>?;
  for (final d in (devices ?? const []).cast<Map<String, dynamic>>()) {
    if (d['name'] == name && d['isAvailable'] == true) {
      return '${d['udid']} ${d['state']}';
    }
  }
  return null;
}
