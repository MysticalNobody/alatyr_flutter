import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/init_identity.dart';
import '../tool/src/init_rewrite.dart';
import '../tool/src/init_validate.dart';

void main() {
  late Directory work;
  late String root;
  late InitReport report;

  String read(String rel) => File(p.join(root, rel)).readAsStringSync();
  bool exists(String rel) =>
      File(p.join(root, rel)).existsSync() ||
      Directory(p.join(root, rel)).existsSync();

  setUpAll(() {
    work = Directory.systemTemp.createTempSync('init_rewrite');
    root = work.path;
    _copyTree(p.join('test', 'fixtures', 'init', 'template'), root);
    final tracked = File(
      p.join('test', 'fixtures', 'init', 'tracked_files.txt'),
    ).readAsLinesSync().where((l) => l.isNotEmpty).toList();
    report = runInit(
      rootDir: root,
      from: deriveIdentity(root),
      to: validateTarget(name: 'my_app', org: 'com.example'),
      trackedFiles: tracked,
      templateUrl: 'https://example.invalid/alatyr',
    );
  });
  tearDownAll(() => work.deleteSync(recursive: true));

  test(
    'Android and Linux get the snake bundle id, Apple the camelCase one',
    () {
      expect(
        read('app/android/app/build.gradle.kts'),
        allOf(
          contains('namespace = "com.example.my_app"'),
          contains('applicationId = "com.example.my_app"'),
          isNot(contains('dev.alatyr')),
        ),
      );
      expect(
        read('app/linux/CMakeLists.txt'),
        contains('set(APPLICATION_ID "com.example.my_app")'),
      );
      expect(
        read('app/ios/Runner.xcodeproj/project.pbxproj'),
        allOf(
          contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.myApp;'),
          contains(
            'PRODUCT_BUNDLE_IDENTIFIER = com.example.myApp.RunnerTests;',
          ),
          contains(
            'PRODUCT_BUNDLE_IDENTIFIER = com.example.myApp.RunnerUITests;',
          ),
          isNot(contains('DEVELOPMENT_TEAM')),
        ),
      );
      expect(
        read('app/macos/Runner/Configs/AppInfo.xcconfig'),
        allOf(
          contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.myApp'),
          contains('PRODUCT_NAME = my_app'),
          contains('Copyright © 2026 com.example.'),
        ),
      );
    },
  );

  test(
    'Kotlin sources and the androidTest runner move to the new package directory',
    () {
      expect(
        read(
          'app/android/app/src/main/kotlin/com/example/my_app/MainActivity.kt',
        ),
        startsWith('package com.example.my_app'),
      );
      expect(
        read(
          'app/android/app/src/androidTest/java/com/example/my_app/MainActivityTest.java',
        ),
        startsWith('package com.example.my_app;'),
      );
      expect(exists('app/android/app/src/main/kotlin/dev'), isFalse);
      expect(exists('app/android/app/src/androidTest/java/dev'), isFalse);
    },
  );

  test('display names, titles and the patrol block are rewritten', () {
    expect(
      read('app/ios/Runner/Info.plist'),
      allOf(contains('<string>My App</string>'), isNot(contains('Alatyr'))),
    );
    expect(
      read('app/android/app/src/main/AndroidManifest.xml'),
      contains('android:label="My App"'),
    );
    expect(read('app/web/manifest.json'), contains('"name": "My App"'));
    expect(
      read('app/windows/runner/Runner.rc'),
      allOf(
        contains('"ProductName", "My App"'),
        contains('"CompanyName", "com.example"'),
      ),
    );
    expect(
      read('app/pubspec.yaml'),
      allOf(
        contains('name: my_app'),
        contains('app_name: My App'),
        contains('package_name: com.example.my_app'),
        contains('bundle_id: com.example.myApp'),
      ),
    );
  });

  test(
    'Dart sources, tests and the workspace are renamed; descriptions are product text',
    () {
      expect(
        read('app/test/app_test.dart'),
        contains("import 'package:my_app/app.dart';"),
      );
      expect(
        read('app/lib/bootstrap/app_dependencies.dart'),
        contains("name: 'my_app'"),
      );
      expect(read('pubspec.yaml'), startsWith('name: my_app_workspace'));
      expect(read('docs/reference/package_graph.yaml'), contains('my_app:'));
      expect(
        read('app/pubspec.yaml'),
        contains('description: My App Flutter app.'),
      );
      expect(
        read('app/web/index.html'),
        contains('content="My App Flutter app."'),
      );
      expect(
        read('test/purity_checker_test.dart'),
        contains('"root": "my_app_workspace"'),
      );
    },
  );

  test(
    'template machinery is deleted and README stubs written; ADRs and binaries are untouched',
    () {
      for (final gone in [
        'tool/init.dart',
        'tool/src/init_identity.dart',
        'tool/src/init_rewrite.dart',
        'tool/template_smoke.sh',
        '.github/workflows/template-smoke.yml',
        'docs/superpowers',
        'test/template_identity_test.dart',
      ]) {
        expect(exists(gone), isFalse, reason: gone);
      }
      expect(
        read('README.md'),
        allOf(
          startsWith('# My App'),
          contains('https://example.invalid/alatyr'),
          contains('docs/README.md'),
        ),
      );
      expect(read('app/README.md'), startsWith('# My App'));
      expect(
        read('docs/adr/0006-working-placeholder-instantiation.md'),
        contains('alatyr_starter'),
      );
      expect(
        read('docs/architecture/01-overview.md'),
        allOf(contains('my_app'), isNot(contains('alatyr_starter'))),
      );
      expect(
        File(p.join(root, 'app/web/sqlite3.wasm')).readAsBytesSync(),
        contains(0),
      );
      expect(read('AGENTS.md'), isNot(contains('my_app')));
    },
  );

  ProcessResult formatCheck(String dir, List<String> files) => Process.runSync(
    Platform.resolvedExecutable, // the pinned SDK's formatter, not PATH's
    ['format', '--output=none', '--set-exit-if-changed', ...files],
    workingDirectory: dir,
  );

  test('the report lists what changed; a short name needs no reformatting', () {
    expect(report.deleted, contains('docs/superpowers'));
    expect(report.movedDirs, hasLength(2));
    expect(
      report.changedDartFiles,
      containsAll([
        'app/lib/app.dart',
        'app/lib/bootstrap/app_dependencies.dart',
        'app/test/app_test.dart',
      ]),
    );
    expect(formatCheck(root, report.changedDartFiles).exitCode, 0);
  });

  test(
    'a long name breaks formatting until the CLI format step runs (spec section 9 step 7)',
    () {
      final dir = Directory.systemTemp.createTempSync('init_long');
      addTearDown(() => dir.deleteSync(recursive: true));
      _copyTree(p.join('test', 'fixtures', 'init', 'template'), dir.path);
      final tracked = File(
        p.join('test', 'fixtures', 'init', 'tracked_files.txt'),
      ).readAsLinesSync().where((l) => l.isNotEmpty).toList();
      final r = runInit(
        rootDir: dir.path,
        from: deriveIdentity(dir.path),
        to: validateTarget(
          name: 'very_long_application_name_for_formatting_checks',
          org: 'io.extremely.lengthy.organization',
        ),
        trackedFiles: tracked,
      );
      // RED before the format step: the longer name rewraps app_dependencies.dart.
      expect(
        formatCheck(dir.path, r.changedDartFiles).exitCode,
        isNot(0),
        reason:
            'the long name must require reformatting, or this test proves nothing',
      );
      final formatted = formatChangedDart(
        rootDir: dir.path,
        files: r.changedDartFiles,
        dartExecutable: Platform.resolvedExecutable,
      );
      expect(formatted.exitCode, 0, reason: '${formatted.stderr}');
      expect(formatCheck(dir.path, r.changedDartFiles).exitCode, 0);
    },
  );

  test('a surviving token is a loud postcondition failure', () {
    final dir = Directory.systemTemp.createTempSync('init_post');
    addTearDown(() => dir.deleteSync(recursive: true));
    _copyTree(p.join('test', 'fixtures', 'init', 'template'), dir.path);
    // A tracked file the rewriter treats as binary (NUL first) but that still
    // carries a token: the rewrite skips it, the postcondition must not.
    File(
      p.join(dir.path, 'app/extra.bin'),
    ).writeAsBytesSync([0, ...'dev.alatyr.starter'.codeUnits]);
    final tracked = [
      ...File(
        p.join('test', 'fixtures', 'init', 'tracked_files.txt'),
      ).readAsLinesSync().where((l) => l.isNotEmpty),
      'app/extra.bin',
    ];
    expect(
      () => runInit(
        rootDir: dir.path,
        from: deriveIdentity(dir.path),
        to: validateTarget(name: 'my_app', org: 'com.example'),
        trackedFiles: tracked,
      ),
      throwsA(isA<InitPostconditionException>()),
    );
  });
}

/// Materialises the fixture tree, dropping the `.txt` suffix every fixture
/// file carries (no fixture may end in `.dart`: root `dart test` and
/// `dart format` would pick it up).
void _copyTree(String from, String to) {
  for (final entity in Directory(
    from,
  ).listSync(recursive: true, followLinks: false)) {
    final rel = p.relative(entity.path, from: from);
    if (entity is Directory) {
      Directory(p.join(to, rel)).createSync(recursive: true);
    } else if (entity is File) {
      final target = rel.endsWith('.txt')
          ? rel.substring(0, rel.length - 4)
          : rel;
      File(p.join(to, target))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}
