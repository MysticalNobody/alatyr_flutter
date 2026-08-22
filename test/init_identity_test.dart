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
