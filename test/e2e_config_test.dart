import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/e2e_config.dart';

String fixture(String name) =>
    File(p.join('test', 'fixtures', 'e2e', name)).readAsStringSync();

void main() {
  test('loads the spec-shaped config', () {
    final c = loadE2eConfig(fixture('valid.yaml'), sourcePath: 'valid.yaml');
    expect(c.defaultPlatform, E2ePlatform.android);
    expect(c.android.avdName, 'e2e_pixel');
    expect(c.android.deviceProfile, 'pixel_7');
    expect(c.android.apiLevel, 34);
    expect(
      c.android.systemImageFor(HostArch.x86_64),
      'system-images;android-34;google_apis;x86_64',
    );
    expect(
      c.android.systemImageFor(HostArch.arm64),
      'system-images;android-34;google_apis;arm64-v8a',
    );
    expect(c.ios.simulatorName, 'e2e_iphone');
    expect(c.ios.deviceType, 'iPhone 16');
    expect(c.ios.runtime, 'iOS 18.0');
  });

  test('unknown default_platform is a config error', () {
    final src = fixture('valid.yaml').replaceFirst('android\n', 'web\n');
    expect(
      () => loadE2eConfig(src, sourcePath: 'x'),
      throwsA(isA<E2eConfigException>()),
    );
  });

  test(
    'a system image whose API level disagrees with api_level is rejected',
    () {
      final src = fixture('valid.yaml').replaceFirst(
        'android-34;google_apis;x86_64',
        'android-35;google_apis;x86_64',
      );
      expect(
        () => loadE2eConfig(src, sourcePath: 'x'),
        throwsA(predicate((e) => e.toString().contains('pins API 35'))),
      );
    },
  );

  test('a missing host-arch image is rejected (no silent fallback)', () {
    final src = fixture(
      'valid.yaml',
    ).replaceFirst(RegExp(r'    arm64:.*\n'), '');
    expect(
      () => loadE2eConfig(src, sourcePath: 'x'),
      throwsA(predicate((e) => e.toString().contains('missing arm64'))),
    );
  });

  test('api_level must be an int, not a string', () {
    final src = fixture(
      'valid.yaml',
    ).replaceFirst('api_level: 34', 'api_level: "34"');
    expect(
      () => loadE2eConfig(src, sourcePath: 'x'),
      throwsA(predicate((e) => e.toString().contains('api_level'))),
    );
  });

  test('ios.runtime shape is validated', () {
    final src = fixture('valid.yaml').replaceFirst('iOS 18.0', 'iOS18');
    expect(
      () => loadE2eConfig(src, sourcePath: 'x'),
      throwsA(predicate((e) => e.toString().contains('ios.runtime'))),
    );
  });

  test(
    'string fields with shell-unsafe characters are rejected by the loader',
    () {
      for (final bad in ["pixel'7", 'pixel\n7', 'pixel\t7']) {
        final src = fixture('valid.yaml').replaceFirst('pixel_7', bad);
        expect(
          () => loadE2eConfig(src, sourcePath: 'x'),
          throwsA(isA<E2eConfigException>()),
          reason: bad,
        );
      }
    },
  );

  test('env dump lists every key bash needs', () {
    final c = loadE2eConfig(fixture('valid.yaml'), sourcePath: 'valid.yaml');
    final env = envLines(c);
    expect(
      env,
      containsAll([
        'DEFAULT_PLATFORM=android',
        'ANDROID_AVD_NAME=e2e_pixel',
        'ANDROID_DEVICE_PROFILE=pixel_7',
        'ANDROID_API_LEVEL=34',
        'ANDROID_SYSTEM_IMAGE_ARM64=system-images;android-34;google_apis;arm64-v8a',
        'ANDROID_SYSTEM_IMAGE_X86_64=system-images;android-34;google_apis;x86_64',
        'IOS_SIMULATOR_NAME=e2e_iphone',
        'IOS_DEVICE_TYPE=iPhone 16',
        'IOS_RUNTIME=iOS 18.0',
      ]),
    );
  });
}
