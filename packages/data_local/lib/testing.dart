/// Test-only entry point. `drift/native.dart` reaches `dart:ffi`, so this
/// library must stay out of `data_local.dart`: the production library is
/// what `app/` compiles for every platform, including web.
library;

import 'package:drift/native.dart';

import 'src/app_database.dart';

/// A fresh in-memory [AppDatabase]: nothing touches disk, every call is a
/// new database.
AppDatabase inMemoryAppDatabase() => AppDatabase(NativeDatabase.memory());
