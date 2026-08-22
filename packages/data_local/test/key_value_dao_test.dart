import 'package:data_local/data_local.dart';
import 'package:data_local/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = inMemoryAppDatabase());
  // Plain `test()` (no FakeAsync zone): awaiting close() here is fine. In
  // `testWidgets` it is not - see the widget-test exemplars in
  // packages/feature_settings/test/ and app/test/.
  tearDown(() => db.close());

  test('write then read roundtrip', () async {
    await db.keyValueDao.write('theme', 'dark');
    expect(await db.keyValueDao.read('theme'), 'dark');
  });

  test('write overwrites an existing value (upsert)', () async {
    await db.keyValueDao.write('theme', 'dark');
    await db.keyValueDao.write('theme', 'light');
    expect(await db.keyValueDao.read('theme'), 'light');
  });

  test('read of a missing key returns null', () async {
    expect(await db.keyValueDao.read('missing'), isNull);
  });

  test('remove deletes the key; removing a missing key is a no-op', () async {
    await db.keyValueDao.write('theme', 'dark');
    await db.keyValueDao.remove('theme');
    expect(await db.keyValueDao.read('theme'), isNull);
    await db.keyValueDao.remove('theme');
  });

  test('watch emits the current value first, then every change', () async {
    await db.keyValueDao.write('theme', 'dark');
    final emitted = <String?>[];
    final sub = db.keyValueDao.watch('theme').listen(emitted.add);
    addTearDown(sub.cancel);

    await pumpEventQueue();
    expect(emitted, ['dark'], reason: 'first emission is the current row');
    await db.keyValueDao.write('theme', 'light');
    await pumpEventQueue();
    expect(emitted, ['dark', 'light']);
    await db.keyValueDao.remove('theme');
    await pumpEventQueue();
    expect(emitted, ['dark', 'light', null]);
  });

  test('watch on a missing key emits null first', () async {
    expect(await db.keyValueDao.watch('nope').first, isNull);
  });

  test('keys are independent', () async {
    await db.keyValueDao.write('a', '1');
    await db.keyValueDao.write('b', '2');
    expect(await db.keyValueDao.read('a'), '1');
    expect(await db.keyValueDao.read('b'), '2');
  });

  test(
    'watch does not re-emit when another key changes or the same value is rewritten',
    () async {
      await db.keyValueDao.write('theme', 'dark');
      final emitted = <String?>[];
      final sub = db.keyValueDao.watch('theme').listen(emitted.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await db.keyValueDao.write('other', 'x');
      await db.keyValueDao.write('theme', 'dark');
      await pumpEventQueue();

      expect(emitted, ['dark']);
    },
  );
}
