import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Fake adb: reports exactly one running emulator and answers the console
/// query the way `E2E_FAKE_CONSOLE` dictates - `ok` (name plus adb's trailing
/// `OK` line), `partial` (the name is printed, adb then fails - the shape of a
/// SIGPIPE from `head -n 1` closing the pipe) or `fail` (console unreachable).
const _fakeAdb = r'''#!/usr/bin/env bash
if [[ "${1:-}" == "devices" ]]; then
  echo "List of devices attached"
  printf 'emulator-5554\tdevice\n'
  exit 0
fi
if [[ "${3:-}" == "emu" && "${4:-}" == "avd" && "${5:-}" == "name" ]]; then
  case "${E2E_FAKE_CONSOLE:-ok}" in
    ok)      printf '%s\r\nOK\r\n' "${E2E_FAKE_AVD:-}"; exit 0 ;;
    partial) printf '%s\r\n' "${E2E_FAKE_AVD:-}"; exit 1 ;;
    fail)    echo "error: could not connect to TCP port 5554" >&2; exit 1 ;;
  esac
fi
exit 0
''';

/// Fake fvm: answers the two questions tool/e2e.sh asks it (the patrol_cli
/// banner and the pinned Flutter path), echoes the patrol invocation instead
/// of running a build, and forwards every other `fvm dart ...` call to the
/// real dart that runs this test.
const _fakeFvm = r'''#!/usr/bin/env bash
if [[ "${1:-}" == "exec" && "${2:-}" == "which" ]]; then
  if [[ "${E2E_FAKE_FLUTTER:-ok}" == "fail" ]]; then
    echo "fvm: could not resolve the pinned SDK" >&2
    exit 1
  fi
  echo "/opt/fake/bin/flutter"
  exit 0
fi
if [[ "${1:-}" == "dart" && "${2:-}" == "pub" ]]; then
  shift
  case "$*" in
    *--version*) echo "patrol_cli v${E2E_FAKE_PATROL_VERSION:-0.0.0}" ;;
    *)           echo "PATROL_INVOKED $*" ;;
  esac
  exit 0
fi
if [[ "${1:-}" == "dart" ]]; then
  shift
  exec "$E2E_FAKE_DART" "$@"
fi
echo "unexpected fvm call: $*" >&2
exit 99
''';

/// Drives `tool/e2e.sh` against a faked Android SDK and a faked `fvm`, so the
/// device-selection branches run with no emulator, no patrol install and no
/// real toolchain. What is under test is the error contract: a hiccup in the
/// tooling must surface as exit 3 with a reason on stderr, never as a bare
/// non-zero exit that reads like a failed test run.
void main() {
  late Directory tmp;
  late String fakeBin;
  late String fakeSdk;
  late String patrolVersion;
  late String avdName;

  void writeExecutable(String path, String body) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(body);
    Process.runSync('chmod', ['+x', path]);
  }

  Future<ProcessResult> runE2e(
    List<String> args, {
    String console = 'ok',
    String flutter = 'ok',
  }) => Process.run(
    'bash',
    ['tool/e2e.sh', ...args],
    environment: <String, String>{
      'PATH': '$fakeBin:${Platform.environment['PATH']}',
      'ANDROID_HOME': fakeSdk,
      'CI': '',
      'E2E_FAKE_DART': Platform.resolvedExecutable,
      'E2E_FAKE_AVD': avdName,
      'E2E_FAKE_CONSOLE': console,
      'E2E_FAKE_FLUTTER': flutter,
      'E2E_FAKE_PATROL_VERSION': patrolVersion,
    },
  );

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('e2e_script');
    fakeBin = '${tmp.path}/bin';
    fakeSdk = '${tmp.path}/sdk';
    writeExecutable('$fakeBin/fvm', _fakeFvm);
    writeExecutable('$fakeSdk/platform-tools/adb', _fakeAdb);
    for (final stub in <String>[
      '$fakeSdk/cmdline-tools/latest/bin/avdmanager',
      '$fakeSdk/cmdline-tools/latest/bin/sdkmanager',
      '$fakeSdk/emulator/emulator',
    ]) {
      writeExecutable(stub, '#!/usr/bin/env bash\nexit 0\n');
    }
    // Both values are read from the shipped sources, so the pin and the
    // declared AVD can change without touching this test.
    patrolVersion = RegExp(
      r'^PATROL_CLI_VERSION="([0-9.]+)"',
      multiLine: true,
    ).firstMatch(File('tool/e2e.sh').readAsStringSync())!.group(1)!;
    avdName = '';
    final list = await runE2e(['--list']);
    expect(list.exitCode, 0, reason: '${list.stdout}${list.stderr}');
    avdName = RegExp(r'avd=(\S+)').firstMatch(list.stdout as String)!.group(1)!;
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  test(
    'the running declared AVD is reused and patrol gets -d <serial>',
    () async {
      final r = await runE2e(['android']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('using running $avdName (emulator-5554)'));
      expect(r.stdout, contains('PATROL_INVOKED'));
      expect(r.stdout, contains('-d emulator-5554'));
    },
  );

  test(
    'adb failing after it printed the AVD name still reuses that emulator',
    () async {
      final r = await runE2e(['android'], console: 'partial');
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('using running $avdName (emulator-5554)'));
      expect(r.stdout, contains('-d emulator-5554'));
    },
  );

  test('an unreadable emulator console is exit 3 with a reason', () async {
    final r = await runE2e(['android'], console: 'fail');
    expect(r.exitCode, 3, reason: '${r.stdout}${r.stderr}');
    expect(r.stderr, contains('e2e not performed'));
    expect(r.stderr, contains('emulator-5554'));
  });

  test('fvm failing to resolve the pinned Flutter SDK is exit 3', () async {
    final r = await runE2e(['android'], flutter: 'fail');
    expect(r.exitCode, 3, reason: '${r.stdout}${r.stderr}');
    expect(r.stderr, contains('e2e not performed'));
    expect(r.stderr, contains('Flutter SDK'));
  });

  test(
    '-t is resolved against the repository root, in every accepted form',
    () async {
      final absolute = p.absolute(
        'app/integration_test/settings_theme_test.dart',
      );
      for (final form in [
        'app/integration_test/settings_theme_test.dart', // as critical_flows.md spells it
        'integration_test/settings_theme_test.dart', // as patrol itself spells it
        absolute,
      ]) {
        final r = await runE2e(['android', '-t', form]);
        expect(r.exitCode, 0, reason: '$form: ${r.stdout}${r.stderr}');
        expect(r.stdout, contains('-t $absolute'), reason: form);
      }
    },
  );

  test('an unknown -t path is a usage error, not a failed run', () async {
    final r = await runE2e([
      'android',
      '-t',
      'integration_test/nope_test.dart',
    ]);
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    expect(r.stderr, contains('no such test file'));
  });

  test('--list needs no patrol_cli: it is a pure config echo', () async {
    patrolVersion = '0.0.0-not-the-pin';
    addTearDown(() {
      patrolVersion = RegExp(
        r'^PATROL_CLI_VERSION="([0-9.]+)"',
        multiLine: true,
      ).firstMatch(File('tool/e2e.sh').readAsStringSync())!.group(1)!;
    });
    final r = await runE2e(['--list']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('android: avd='));
  });
}
