import 'package:app_core/app_core.dart';
import 'package:data_local/data_local.dart';
import 'package:data_local/testing.dart';
import 'package:feature_settings/src/drift_settings_repository.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDao extends Mock implements KeyValueDao {}

/// Records what the repository logs, so the `logger:` seam is asserted and
/// not merely wired.
final class _RecordingLogger extends AppLogger {
  final List<({LogLevel level, String message})> records = [];

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => records.add((level: level, message: message));
}

void main() {
  group('on a real in-memory database', () {
    late AppDatabase db;
    late DriftSettingsRepository repository;

    setUp(() {
      db = inMemoryAppDatabase();
      repository = DriftSettingsRepository(db.keyValueDao);
    });
    tearDown(() => db.close()); // plain test(): awaiting close is fine here

    test('given nothing is stored, emits system', () async {
      expect(await repository.watchThemeMode().first, ThemeMode.system);
    });

    test('given a stored mode, emits it', () async {
      await db.keyValueDao.write(DriftSettingsRepository.themeModeKey, 'dark');
      expect(await repository.watchThemeMode().first, ThemeMode.dark);
    });

    test(
      'given stored theme is corrupted, settings falls back to system',
      () async {
        final recorder = _RecordingLogger();
        final logged = DriftSettingsRepository(
          db.keyValueDao,
          logger: recorder,
        );
        await db.keyValueDao.write(
          DriftSettingsRepository.themeModeKey,
          'purple',
        );
        expect(await logged.watchThemeMode().first, ThemeMode.system);
        expect(recorder.records, hasLength(1));
        expect(recorder.records.single.level, LogLevel.warn);
        expect(recorder.records.single.message, contains('purple'));
      },
    );

    test(
      'given stored theme is an empty string, settings falls back to system',
      () async {
        final recorder = _RecordingLogger();
        final logged = DriftSettingsRepository(
          db.keyValueDao,
          logger: recorder,
        );
        await db.keyValueDao.write(DriftSettingsRepository.themeModeKey, '');
        expect(await logged.watchThemeMode().first, ThemeMode.system);
        expect(recorder.records, hasLength(1));
        expect(recorder.records.single.level, LogLevel.warn);
      },
    );

    test(
      'given stored theme is unicode garbage, settings falls back to system',
      () async {
        final recorder = _RecordingLogger();
        final logged = DriftSettingsRepository(
          db.keyValueDao,
          logger: recorder,
        );
        await db.keyValueDao.write(
          DriftSettingsRepository.themeModeKey,
          '🎨_未知_🌈',
        );
        expect(await logged.watchThemeMode().first, ThemeMode.system);
        expect(recorder.records, hasLength(1));
        expect(recorder.records.single.level, LogLevel.warn);
        expect(recorder.records.single.message, contains('🎨_未知_🌈'));
      },
    );

    test(
      'saveThemeMode persists and the watch stream emits the new mode',
      () async {
        final emitted = <ThemeMode>[];
        final sub = repository.watchThemeMode().listen(emitted.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();

        expect(
          await repository.saveThemeMode(ThemeMode.light),
          isA<Ok<void>>(),
        );
        await pumpEventQueue();

        expect(emitted, [ThemeMode.system, ThemeMode.light]);
        expect(
          await db.keyValueDao.read(DriftSettingsRepository.themeModeKey),
          'light',
        );
      },
    );
  });

  test(
    'saveThemeMode maps a storage exception to settings.save-failed',
    () async {
      final dao = _MockDao();
      when(() => dao.write(any(), any())).thenThrow(Exception('disk full'));
      final result = await DriftSettingsRepository(
        dao,
      ).saveThemeMode(ThemeMode.dark);
      expect(result.failureOrNull?.code, SettingsFailureCodes.save);
      expect(result.failureOrNull?.cause, isA<Exception>());
    },
  );

  test(
    'saveThemeMode lets a StateError from a closed database propagate uncaught',
    () async {
      final dao = _MockDao();
      when(
        () => dao.write(any(), any()),
      ).thenThrow(StateError('closed database'));
      final repository = DriftSettingsRepository(dao);
      await expectLater(
        repository.saveThemeMode(ThemeMode.dark),
        throwsA(isA<StateError>()),
      );
    },
  );
}
