import 'package:app_core/app_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_store.dart';

/// [SecureStore] backed by `flutter_secure_storage` (Keychain / Keystore /
/// libsecret / DPAPI / WebCrypto).
///
/// Platform notes a consumer must keep: iOS and macOS ship
/// `keychain-access-groups` (empty array) in the app shell's entitlements;
/// put the App Group name into it when App Groups are enabled; Linux needs
/// `libsecret-1-dev` and a running secret service.
///
/// Every operation is `async` and guarded by `on Exception`: the plugin
/// throws `PlatformException` (codes differ per platform, so the TYPE is
/// what we map) and `MissingPluginException` where no implementation is
/// registered; a synchronous throw from the plugin thus surfaces as a
/// rejected future that the guard turns into an [Err].
final class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore(this._storage);

  /// Adapter over the platform plugin with default options.
  const FlutterSecureStore.platform() : this(const FlutterSecureStorage());

  final FlutterSecureStorage _storage;

  @override
  Future<Result<String?>> read(String key) async {
    try {
      return Ok(await _storage.read(key: key));
    } on Exception catch (e) {
      return Err(_failure(SecureStoreFailureCodes.read, 'read', e));
    }
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(_failure(SecureStoreFailureCodes.write, 'write', e));
    }
  }

  @override
  Future<Result<void>> delete(String key) async {
    try {
      await _storage.delete(key: key);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(_failure(SecureStoreFailureCodes.delete, 'delete', e));
    }
  }

  // The failure message names the operation, never the key or the value:
  // failures may end up in logs.
  static AppFailure _failure(String code, String operation, Exception cause) =>
      AppFailure(
        code: code,
        message: 'Secure storage $operation failed',
        cause: cause,
      );
}
