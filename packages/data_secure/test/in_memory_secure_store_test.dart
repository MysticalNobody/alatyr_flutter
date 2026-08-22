import 'package:app_core/app_core.dart';
import 'package:data_secure/data_secure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStore store;
  setUp(() => store = InMemorySecureStore());

  test('read of a missing key is Ok(null)', () async {
    // `Ok` does not override `==` (app_core keeps Result minimal), so
    // assert on the shape, never on instance equality.
    expect(
      await store.read('k'),
      isA<Ok<String?>>().having((r) => r.value, 'value', isNull),
    );
  });

  test('write then read roundtrip', () async {
    expect(await store.write('k', 'v'), isA<Ok<void>>());
    expect((await store.read('k')).valueOrNull, 'v');
  });

  test('delete removes the key and is a no-op when absent', () async {
    await store.write('k', 'v');
    expect(await store.delete('k'), isA<Ok<void>>());
    expect((await store.read('k')).valueOrNull, isNull);
    expect(await store.delete('k'), isA<Ok<void>>());
  });
}
