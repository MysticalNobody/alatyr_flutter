import 'package:app_core/app_core.dart';

/// Failure codes of [SecureStore] operations (`<area>.<reason>`).
abstract final class SecureStoreFailureCodes {
  static const String read = 'secure.read-failed';
  static const String write = 'secure.write-failed';
  static const String delete = 'secure.delete-failed';
}

/// Port for encrypted key-value storage. Runtime secrets (tokens, refresh
/// credentials) live ONLY behind this port - never in drift, prefs, logs or
/// source (hard invariant 4).
abstract interface class SecureStore {
  /// The value for [key], or `Ok(null)` when absent.
  Future<Result<String?>> read(String key);

  /// Persists [value] under [key], overwriting any previous value.
  Future<Result<void>> write(String key, String value);

  /// Removes [key]; `Ok` when it was absent.
  Future<Result<void>> delete(String key);
}
