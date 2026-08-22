import 'package:app_core/app_core.dart';

import 'secure_store.dart';

/// Volatile [SecureStore] for tests, previews and platforms without a
/// secure backend. Nothing is persisted.
final class InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<Result<String?>> read(String key) async => Ok(_values[key]);

  @override
  Future<Result<void>> write(String key, String value) async {
    _values[key] = value;
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(String key) async {
    _values.remove(key);
    return const Ok(null);
  }
}
