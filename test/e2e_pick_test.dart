import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/e2e_pick_device.dart';
import '../tool/e2e_pick_runtime.dart';

String fixture(String name) =>
    File(p.join('test', 'fixtures', 'e2e', name)).readAsStringSync();

void main() {
  test('picks the newest available runtime of the requested major', () {
    expect(
      pickRuntime(fixture('runtimes.json'), major: 18),
      'com.apple.CoreSimulator.SimRuntime.iOS-18-4',
    );
    expect(
      pickRuntime(fixture('runtimes.json'), major: 26),
      'com.apple.CoreSimulator.SimRuntime.iOS-26-2',
    );
  });

  test('no runtime of that major -> null', () {
    expect(pickRuntime(fixture('runtimes.json'), major: 16), isNull);
  });

  test('finds the named device under the runtime and reports its state', () {
    expect(
      pickDevice(
        fixture('devices.json'),
        name: 'e2e_iphone',
        runtime: 'com.apple.CoreSimulator.SimRuntime.iOS-18-4',
      ),
      matches(RegExp(r'^[0-9A-F-]{36} Shutdown$')),
    );
  });

  test('unknown name or runtime -> null', () {
    expect(
      pickDevice(
        fixture('devices.json'),
        name: 'nope',
        runtime: 'com.apple.CoreSimulator.SimRuntime.iOS-18-4',
      ),
      isNull,
    );
    expect(
      pickDevice(
        fixture('devices.json'),
        name: 'e2e_iphone',
        runtime: 'com.apple.CoreSimulator.SimRuntime.iOS-17-4',
      ),
      isNull,
    );
  });
}
