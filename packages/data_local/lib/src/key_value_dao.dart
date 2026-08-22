import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'key_value_dao.g.dart';

/// Key-value access over [KeyValues].
@DriftAccessor(tables: [KeyValues])
class KeyValueDao extends DatabaseAccessor<AppDatabase>
    with _$KeyValueDaoMixin {
  KeyValueDao(super.attachedDatabase);

  Future<String?> read(String key) async {
    final row = await (select(
      keyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) async {
    await into(
      keyValues,
    ).insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: value));
  }

  /// Named `remove`, not `delete`: `DatabaseAccessor` already inherits
  /// `DatabaseConnectionUser.delete(TableInfo)`, so a `delete(String)`
  /// member on a DAO is an invalid override (compile error).
  Future<void> remove(String key) async {
    await (delete(keyValues)..where((t) => t.key.equals(key))).go();
  }

  /// Emits the current value (null when absent) on subscription, then one
  /// value per change of that key. drift re-runs the query on ANY change to
  /// the table, so `distinct()` is what turns "table changed" into "this
  /// key's value changed".
  Stream<String?> watch(String key) =>
      (select(keyValues)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value)
          .distinct();
}
