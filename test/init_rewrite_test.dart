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
      // EVERY entry, not a hand-picked subset: an entry added to the list
      // without a fixture (or dropped from it) must not pass silently.
      for (final gone in templateOnlyPaths) {
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

  /// A private copy of the fixture tree for a test that mutates it.
  String freshTree(String prefix) {
    final dir = Directory.systemTemp.createTempSync(prefix);
    addTearDown(() => dir.deleteSync(recursive: true));
    _copyTree(p.join('test', 'fixtures', 'init', 'template'), dir.path);
    return dir.path;
  }

  List<String> fixtureTracked() => File(
    p.join('test', 'fixtures', 'init', 'tracked_files.txt'),
  ).readAsLinesSync().where((l) => l.isNotEmpty).toList();

  test(
    'every template-only path exists in this repository (renames are caught here)',
    () {
      for (final rel in templateOnlyPaths) {
        expect(
          File(rel).existsSync() || Directory(rel).existsSync(),
          isTrue,
          reason:
              '$rel is on templateOnlyPaths but not in the repository: '
              'init would delete nothing and the path would ship to consumers',
        );
      }
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

  test('the root pubspec description becomes the product workspace line', () {
    expect(
      read('pubspec.yaml'),
      contains('description: My App workspace root.'),
    );
    expect(read('pubspec.yaml'), isNot(contains('Flutter starter')));
  });

  test('a pre-existing DEVELOPMENT_TEAM line survives the rewrite untouched', () {
    // Plausible after opening the template in Xcode once: init rewrites
    // identity tokens, it does not scrub the project file.
    final dir = freshTree('init_team');
    final pbxproj = File(
      p.join(dir, 'app/ios/Runner.xcodeproj/project.pbxproj'),
    );
    pbxproj.writeAsStringSync(
      pbxproj.readAsStringSync().replaceFirst(
        'PRODUCT_BUNDLE_IDENTIFIER = dev.alatyr.starter;',
        'DEVELOPMENT_TEAM = ABCDE12345;\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.alatyr.starter;',
      ),
    );
    runInit(
      rootDir: dir,
      from: deriveIdentity(dir),
      to: validateTarget(name: 'my_app', org: 'com.example'),
      trackedFiles: fixtureTracked(),
    );
    expect(
      pbxproj.readAsStringSync(),
      allOf(
        contains('DEVELOPMENT_TEAM = ABCDE12345;'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.myApp;'),
      ),
    );
  });

  test('a CRLF file is rewritten with its line endings preserved', () {
    final dir = freshTree('init_crlf');
    const rel = 'app/windows/runner/crlf.rc';
    File(p.join(dir, rel)).writeAsStringSync(
      'PRODUCT "Alatyr Starter"\r\nID "dev.alatyr.starter"\r\n',
    );
    runInit(
      rootDir: dir,
      from: deriveIdentity(dir),
      to: validateTarget(name: 'my_app', org: 'com.example'),
      trackedFiles: [...fixtureTracked(), rel],
    );
    expect(
      File(p.join(dir, rel)).readAsStringSync(),
      'PRODUCT "My App"\r\nID "com.example.my_app"\r\n',
    );
  });

  test('a symlinked tracked path is skipped, not followed', () {
    final dir = freshTree('init_link');
    final outside = Directory.systemTemp.createTempSync('init_outside');
    addTearDown(() => outside.deleteSync(recursive: true));
    final target = File(p.join(outside.path, 'target.md'))
      ..writeAsStringSync('# Alatyr Starter lives in dev.alatyr.starter\n');
    const rel = 'docs/architecture/linked.md';
    Link(p.join(dir, rel)).createSync(target.path);
    final r = runInit(
      rootDir: dir,
      from: deriveIdentity(dir),
      to: validateTarget(name: 'my_app', org: 'com.example'),
      trackedFiles: [...fixtureTracked(), rel],
    );
    expect(r.skipped, contains(rel));
    expect(r.rewritten, isNot(contains(rel)));
    // The link's target lives outside the checkout: untouched, and not a
    // postcondition survivor either (the scan skips links too).
    expect(
      target.readAsStringSync(),
      '# Alatyr Starter lives in dev.alatyr.starter\n',
    );
  });

  test('a token surviving the Kotlin move is a postcondition failure', () {
    final dir = freshTree('init_moved');
    // Untracked (so the rewrite pass never sees it), but the move carries it
    // into the new package directory: only the moved-target scan can catch it.
    File(
      p.join(
        dir,
        'app/android/app/src/main/kotlin/dev/alatyr/starter/Extra.kt',
      ),
    ).writeAsStringSync('package dev.alatyr.starter\n');
    expect(
      () => runInit(
        rootDir: dir,
        from: deriveIdentity(dir),
        to: validateTarget(name: 'my_app', org: 'com.example'),
        trackedFiles: fixtureTracked(),
      ),
      throwsA(
        isA<InitPostconditionException>().having(
          (e) => e.message,
          'message',
          contains('Extra.kt'),
        ),
      ),
    );
  });

  test('formatChangedDart reports a Dart file it cannot parse', () {
    final dir = freshTree('init_format_fail');
    const rel = 'app/lib/broken.dart';
    File(p.join(dir, rel)).writeAsStringSync('void main( {\n');
    final result = formatChangedDart(
      rootDir: dir,
      files: [rel],
      dartExecutable: Platform.resolvedExecutable,
    );
    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains(rel));
  });

  test(
    'untracked files (e.g. the .ru.md doc twins) keep the placeholder tokens',
    () {},
    skip:
        'deliberate: only tracked files are rewritten - git ls-files defines '
        'the scope, and the CLI usage text says so. Widening it to untracked '
        'files would rewrite build output and local scratch files.',
  );

  test(
    'a dirty tree is rewritten from the working copy, not from the index',
    () {},
    skip:
        'deliberate: runInit only ever reads the working copy '
        '(File.readAsBytesSync), so there is no index path to diverge from; a '
        'test would assert the absence of code that was never written.',
  );

  test(
    'an unreadable tracked file aborts after the destructive step',
    () {},
    skip:
        'deliberate: chmod 000 does not deny root (a containerized gate host '
        'typically runs as root), so the '
        'scenario is not reproducible on every gate host. The CLI now prints '
        'the FileSystemException message plus the documented recovery command '
        'instead of a stack trace (tool/init.dart _guarded).',
  );

  test(
    'a token inside a base64 blob is rewritten without awareness of the encoding',
    () {},
    skip:
        'deliberate: whole-token text substitution is the documented '
        'mechanism (ADR-0006); detecting encoded regions would need a decoder '
        'per format. The postcondition scan still catches a surviving token.',
  );

  test(
    'running runInit twice against an already instantiated tree',
    () {},
    skip:
        'deliberate: the CLI deletes itself in step 1, so a rerun is '
        'structurally impossible; post-init identity changes are a manual '
        'operation (spec section 9, deliberate YAGNI).',
  );
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
