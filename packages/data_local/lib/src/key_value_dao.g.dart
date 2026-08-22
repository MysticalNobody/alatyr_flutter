// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'key_value_dao.dart';

// ignore_for_file: type=lint
mixin _$KeyValueDaoMixin on DatabaseAccessor<AppDatabase> {
  $KeyValuesTable get keyValues => attachedDatabase.keyValues;
  KeyValueDaoManager get managers => KeyValueDaoManager(this);
}

class KeyValueDaoManager {
  final _$KeyValueDaoMixin _db;
  KeyValueDaoManager(this._db);
  $$KeyValuesTableTableManager get keyValues =>
      $$KeyValuesTableTableManager(_db.attachedDatabase, _db.keyValues);
}
