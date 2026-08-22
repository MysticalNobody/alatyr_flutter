import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'key_value_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The single on-device database. Tables and DAOs are registered here;
/// schema changes bump [schemaVersion] and add a migration.
///
/// Deliberately NO `drift/native.dart` import in this library: it pulls
/// `dart:ffi` and would make `flutter build web` fail. The in-memory
/// constructor tests use lives in `package:data_local/testing.dart`.
@DriftDatabase(tables: [KeyValues], daos: [KeyValueDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// On-device database named [name]: drift_flutter picks the platform
  /// storage (documents directory on native, IndexedDB/OPFS on web).
  ///
  /// `web` is mandatory for web builds (`driftDatabase` throws without it)
  /// and names the two assets drift needs next to `index.html`:
  /// `sqlite3.wasm` and `drift_worker.js`. The template's app shell does
  /// not ship those binaries yet (M5 carryover); until then web builds
  /// compile and run but persistence fails at open time with a clear
  /// drift error rather than an ArgumentError.
  AppDatabase.open({required String name})
    : super(
        driftDatabase(
          name: name,
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 1;
}
