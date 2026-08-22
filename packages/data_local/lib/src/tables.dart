import 'package:drift/drift.dart';

/// Generic string key -> string value storage for small settings-like data.
/// NOT for secrets (those go through data_secure) - the import validator's
/// secret-leak heuristic scans this package for a reason.
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
