import 'package:yaml/yaml.dart';

const String e2eConfigPath = 'tool/e2e.yaml';

final class E2eConfigException implements Exception {
  E2eConfigException(this.message);
  final String message;
  @override
  String toString() => 'E2eConfigException: $message';
}

enum E2ePlatform { android, ios }

/// Host CPU architectures the Android system image is pinned for.
enum HostArch { arm64, x86_64 }

final class AndroidE2eConfig {
  const AndroidE2eConfig({
    required this.avdName,
    required this.deviceProfile,
    required this.apiLevel,
    required this.systemImages,
  });
  final String avdName;
  final String deviceProfile;
  final int apiLevel;
  final Map<HostArch, String> systemImages;

  String systemImageFor(HostArch arch) =>
      systemImages[arch] ??
      (throw E2eConfigException(
        'android.system_images has no entry for ${arch.name}',
      ));
}

final class IosE2eConfig {
  const IosE2eConfig({
    required this.simulatorName,
    required this.deviceType,
    required this.runtime,
  });
  final String simulatorName;
  final String deviceType;
  final String runtime;
}

final class E2eConfig {
  const E2eConfig({
    required this.defaultPlatform,
    required this.android,
    required this.ios,
  });
  final E2ePlatform defaultPlatform;
  final AndroidE2eConfig android;
  final IosE2eConfig ios;
}

final _sdkmanagerImage = RegExp(r'^system-images;android-(\d+);[^;]+;[^;]+$');
final _iosRuntime = RegExp(r'^iOS \d+(\.\d+)+$');

E2eConfig loadE2eConfig(String yamlSource, {required String sourcePath}) {
  final dynamic root;
  try {
    root = loadYaml(yamlSource);
  } on YamlException catch (e) {
    // A raw newline/tab injected into a scalar (the shell-unsafe-character
    // tests) breaks YAML's own indentation rules before _req ever runs -
    // that must surface as our exception type too, not leak yaml's.
    throw E2eConfigException('$sourcePath: invalid YAML: ${e.message}');
  }
  if (root is! YamlMap) {
    throw E2eConfigException('$sourcePath: top level must be a map');
  }
  final platformName = _req<String>(root, 'default_platform', sourcePath);
  final defaultPlatform = E2ePlatform.values.asNameMap()[platformName];
  if (defaultPlatform == null) {
    throw E2eConfigException(
      '$sourcePath: default_platform must be android or ios, got "$platformName"',
    );
  }
  final android = _req<YamlMap>(root, 'android', sourcePath);
  final apiLevel = _req<int>(android, 'api_level', '$sourcePath: android');
  final rawImages = _req<YamlMap>(
    android,
    'system_images',
    '$sourcePath: android',
  );
  final images = <HostArch, String>{};
  for (final entry in rawImages.entries) {
    final arch = HostArch.values.asNameMap()[entry.key.toString()];
    if (arch == null) {
      throw E2eConfigException(
        '$sourcePath: android.system_images.${entry.key} is not a known host arch '
        '(${HostArch.values.map((a) => a.name).join(', ')})',
      );
    }
    final image = entry.value.toString();
    final m = _sdkmanagerImage.firstMatch(image);
    if (m == null) {
      throw E2eConfigException(
        '$sourcePath: android.system_images.${arch.name} "$image" is not an sdkmanager path '
        '(system-images;android-<api>;<tag>;<abi>)',
      );
    }
    if (int.parse(m.group(1)!) != apiLevel) {
      throw E2eConfigException(
        '$sourcePath: android.system_images.${arch.name} pins API ${m.group(1)} but android.api_level is $apiLevel',
      );
    }
    images[arch] = image;
  }
  for (final arch in HostArch.values) {
    if (!images.containsKey(arch)) {
      throw E2eConfigException(
        '$sourcePath: android.system_images is missing ${arch.name} (one image per host architecture)',
      );
    }
  }
  final ios = _req<YamlMap>(root, 'ios', sourcePath);
  final runtime = _req<String>(ios, 'runtime', '$sourcePath: ios');
  if (!_iosRuntime.hasMatch(runtime)) {
    throw E2eConfigException(
      '$sourcePath: ios.runtime must look like "iOS 18.0", got "$runtime"',
    );
  }
  return E2eConfig(
    defaultPlatform: defaultPlatform,
    android: AndroidE2eConfig(
      avdName: _req<String>(android, 'avd_name', '$sourcePath: android'),
      deviceProfile: _req<String>(
        android,
        'device_profile',
        '$sourcePath: android',
      ),
      apiLevel: apiLevel,
      systemImages: images,
    ),
    ios: IosE2eConfig(
      simulatorName: _req<String>(ios, 'simulator_name', '$sourcePath: ios'),
      deviceType: _req<String>(ios, 'device_type', '$sourcePath: ios'),
      runtime: runtime,
    ),
  );
}

/// `KEY=value` lines for tool/e2e.sh (the entrypoint single-quotes the
/// values; `_req` rejects quotes and control characters so that is safe).
List<String> envLines(E2eConfig c) => [
  'DEFAULT_PLATFORM=${c.defaultPlatform.name}',
  'ANDROID_AVD_NAME=${c.android.avdName}',
  'ANDROID_DEVICE_PROFILE=${c.android.deviceProfile}',
  'ANDROID_API_LEVEL=${c.android.apiLevel}',
  'ANDROID_SYSTEM_IMAGE_ARM64=${c.android.systemImageFor(HostArch.arm64)}',
  'ANDROID_SYSTEM_IMAGE_X86_64=${c.android.systemImageFor(HostArch.x86_64)}',
  'IOS_SIMULATOR_NAME=${c.ios.simulatorName}',
  'IOS_DEVICE_TYPE=${c.ios.deviceType}',
  'IOS_RUNTIME=${c.ios.runtime}',
];

// Values travel to bash as single-quoted words: no quotes, no control
// characters (the loader is the only place that can reject them early).
final _shellUnsafe = RegExp("[\\x00-\\x1f']");

T _req<T>(YamlMap map, String key, String where) {
  final value = map[key];
  if (value is! T) {
    throw E2eConfigException(
      '$where: "$key" is required and must be $T${value == null ? ' (missing)' : ''}',
    );
  }
  if (value is String && _shellUnsafe.hasMatch(value)) {
    throw E2eConfigException(
      '$where: "$key" must not contain quotes or control characters',
    );
  }
  return value;
}
