import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/init_identity.dart';

void main() {
  late Directory work;

  // The fixture files are stored with a `.txt` suffix (no fixture may end in
  // `.dart`), so deriveIdentity - which reads real file names - needs the
  // tree materialised first, exactly as init_rewrite_test.dart does.
  setUpAll(() {
    work = Directory.systemTemp.createTempSync('init_identity');
    _copyTree(p.join('test', 'fixtures', 'init', 'template'), work.path);
  });
  tearDownAll(() => work.deleteSync(recursive: true));

  /// A private copy of the fixture tree, for the tests that break it.
  String brokenTree() {
    final dir = Directory.systemTemp.createTempSync('init_identity_broken');
    addTearDown(() => dir.deleteSync(recursive: true));
    _copyTree(p.join('test', 'fixtures', 'init', 'template'), dir.path);
    return dir.path;
  }

  void edit(String root, String rel, Pattern from, String to) {
    final file = File(p.join(root, rel));
    file.writeAsStringSync(file.readAsStringSync().replaceFirst(from, to));
  }

  Matcher throwsStateErrorContaining(String fragment) => throwsA(
    isA<StateError>().having((e) => e.message, 'message', contains(fragment)),
  );

  test(
    'derives the placeholder identity from the app shell, never from a literal',
    () {
      final id = deriveIdentity(work.path);
      expect(id.packageName, 'alatyr_starter');
      expect(id.bundleId, 'dev.alatyr.starter');
      expect(id.org, 'dev.alatyr');
      expect(id.displayName, 'Alatyr Starter');
      expect(id.workspaceName, 'alatyr_workspace');
    },
  );

  test('the real repository derives the same identity', () {
    final id = deriveIdentity('.');
    expect(id.packageName, 'alatyr_starter');
    expect(id.bundleId, 'dev.alatyr.starter');
  });

  test('a pubspec without a name: key is a StateError, never "null"', () {
    final root = brokenTree();
    edit(root, 'pubspec.yaml', RegExp('^name: .*\n', multiLine: true), '');
    expect(
      () => deriveIdentity(root),
      throwsStateErrorContaining('pubspec.yaml has no "name:" key'),
    );
    // The bug this guards: `null.toString()` silently becoming the identity.
    try {
      deriveIdentity(root);
      fail('deriveIdentity must throw');
    } on StateError catch (e) {
      expect(e.message, isNot(contains('"null"')));
    }

    final app = brokenTree();
    edit(app, 'app/pubspec.yaml', RegExp('^name: .*\n', multiLine: true), '');
    expect(
      () => deriveIdentity(app),
      throwsStateErrorContaining('app/pubspec.yaml has no "name:" key'),
    );
  });

  test('a missing applicationId is a StateError naming the gradle file', () {
    final root = brokenTree();
    edit(
      root,
      'app/android/app/build.gradle.kts',
      RegExp(r'applicationId\s*=.*'),
      'applicationIdSuffix = ".debug"',
    );
    expect(
      () => deriveIdentity(root),
      throwsStateErrorContaining(
        'applicationId not found in app/android/app/build.gradle.kts',
      ),
    );
  });

  test('a missing CFBundleDisplayName is a StateError naming Info.plist', () {
    final root = brokenTree();
    edit(
      root,
      'app/ios/Runner/Info.plist',
      '<key>CFBundleDisplayName</key>',
      '<key>CFBundleDisplayNameX</key>',
    );
    expect(
      () => deriveIdentity(root),
      throwsStateErrorContaining(
        'CFBundleDisplayName not found in app/ios/Runner/Info.plist',
      ),
    );
  });

  test('the graph must have exactly one app_root, and app/ must agree', () {
    final two = brokenTree();
    final graph = File(p.join(two, 'docs/reference/package_graph.yaml'));
    graph.writeAsStringSync(
      '${graph.readAsStringSync()}\n  second_app:\n    kind: app_root\n    depends_on: []\n',
    );
    expect(
      () => deriveIdentity(two),
      throwsStateErrorContaining('exactly one app_root'),
    );

    final mismatch = brokenTree();
    edit(
      mismatch,
      'app/pubspec.yaml',
      RegExp('^name: .*', multiLine: true),
      'name: renamed_app',
    );
    expect(
      () => deriveIdentity(mismatch),
      throwsStateErrorContaining('!= graph app_root'),
    );
  });

  test('a checkout without app/ios says so instead of throwing a path error', () {
    final root = brokenTree();
    Directory(p.join(root, 'app', 'ios')).deleteSync(recursive: true);
    expect(
      () => deriveIdentity(root),
      throwsStateErrorContaining(
        'app/ios/Runner/Info.plist not found — init expects the full platform set of the template',
      ),
    );
  });

  test('workspace member names are read from the root pubspec', () {
    // The fixture workspace lists packages/app_core, packages/feature_settings
    // and app; only the ones that carry a pubspec can be named.
    expect(workspaceMemberNames(work.path), contains('alatyr_starter'));
    expect(workspaceMemberNames('.'), containsAll(['app_core', 'app_config']));
  });
}

/// Materialises the fixture tree, dropping the `.txt` suffix every fixture
/// file carries. Duplicated in init_rewrite_test.dart on purpose: both files
/// are template-only and init deletes them together, so a shared helper
/// would only add a third file to delete.
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
