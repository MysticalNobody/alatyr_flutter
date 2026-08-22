import 'package:app_core/app_core.dart';
import 'package:data_secure/data_secure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late FlutterSecureStore store;

  setUp(() {
    storage = _MockStorage();
    store = FlutterSecureStore(storage);
  });

  test('read delegates with the named key', () async {
    when(() => storage.read(key: 'k')).thenAnswer((_) async => 'v');
    expect(
      await store.read('k'),
      isA<Ok<String?>>().having((r) => r.value, 'value', 'v'),
    );
    verify(() => storage.read(key: 'k')).called(1);
    verifyNoMoreInteractions(storage);
  });

  test('write delegates key and value', () async {
    when(() => storage.write(key: 'k', value: 'v')).thenAnswer((_) async {});
    expect(await store.write('k', 'v'), isA<Ok<void>>());
    verify(() => storage.write(key: 'k', value: 'v')).called(1);
  });

  test('delete delegates with the named key', () async {
    when(() => storage.delete(key: 'k')).thenAnswer((_) async {});
    expect(await store.delete('k'), isA<Ok<void>>());
    verify(() => storage.delete(key: 'k')).called(1);
  });

  test(
    'a PlatformException on read becomes Err(secure.read-failed) with the cause',
    () async {
      final boom = PlatformException(
        code: 'Exception',
        message: 'keychain locked',
      );
      when(() => storage.read(key: 'k')).thenThrow(boom);
      final result = await store.read('k');
      final failure = result.failureOrNull;
      expect(failure?.code, SecureStoreFailureCodes.read);
      expect(failure?.cause, same(boom));
    },
  );

  test('an async failure on write becomes Err(secure.write-failed)', () async {
    when(
      () => storage.write(key: 'k', value: 'v'),
    ).thenAnswer((_) async => throw PlatformException(code: 'Exception'));
    expect(
      (await store.write('k', 'v')).failureOrNull?.code,
      SecureStoreFailureCodes.write,
    );
  });

  test(
    'a MissingPluginException on delete becomes Err(secure.delete-failed)',
    () async {
      when(() => storage.delete(key: 'k')).thenThrow(MissingPluginException());
      expect(
        (await store.delete('k')).failureOrNull?.code,
        SecureStoreFailureCodes.delete,
      );
    },
  );
}
