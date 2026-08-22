import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:feature_settings/src/bloc/settings_bloc.dart';
import 'package:feature_settings/src/bloc/settings_event.dart';
import 'package:feature_settings/src/settings_repository.dart';
import 'package:feature_settings/src/ui/settings_screen.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

/// Deterministic in-memory repository: a broadcast stream that replays the
/// current value to new listeners, and an optional forced save failure.
final class _FakeRepository implements SettingsRepository {
  _FakeRepository({this.failSaves = false, this.neverLoads = false});

  final bool failSaves;

  /// A load that never completes (storage hanging): the screen stays in
  /// its loading state for the whole test.
  final bool neverLoads;
  ThemeMode _current = ThemeMode.system;
  final _changes = StreamController<ThemeMode>.broadcast();

  @override
  Stream<ThemeMode> watchThemeMode() async* {
    if (!neverLoads) yield _current;
    yield* _changes.stream;
  }

  @override
  Future<Result<void>> saveThemeMode(ThemeMode mode) async {
    if (failSaves) {
      return const Err(
        AppFailure(code: SettingsFailureCodes.save, message: 'nope'),
      );
    }
    _current = mode;
    _changes.add(mode);
    return const Ok(null);
  }
}

/// The widget tree owns the bloc (`BlocProvider(create:)` closes it at
/// disposal). Nothing here is closed through an awaited tearDown: a
/// `Bloc.close()` / `StreamController.close()` whose completion depends on
/// objects created inside the FakeAsync zone of `testWidgets` never
/// completes once the body has returned, and the test hangs (verified).
Future<void> _pump(PatrolTester $, _FakeRepository repository) =>
    $.pumpWidgetAndSettle(
      MaterialApp(
        home: BlocProvider(
          create: (_) => SettingsBloc(repository)..add(const SettingsStarted()),
          child: const SettingsScreen(),
        ),
      ),
    );

// Patrol finders all the way down; `$.tester.widget<T>` is the only way to
// read a widget property, so that part is unavoidable.
bool _isSelected(PatrolTester $, ThemeMode mode) => $.tester
    .widget<ListTile>($(SettingsKeys.themeModeTile(mode)).$(ListTile))
    .selected;

void main() {
  patrolWidgetTest(
    'renders one keyed tile per theme mode, system selected by default',
    ($) async {
      await _pump($, _FakeRepository());
      expect($(SettingsKeys.screen), findsOneWidget);
      for (final mode in ThemeMode.values) {
        expect($(SettingsKeys.themeModeTile(mode)), findsOneWidget);
      }
      expect(_isSelected($, ThemeMode.system), isTrue);
      expect(_isSelected($, ThemeMode.dark), isFalse);
      expect($(SettingsKeys.failureBanner).exists, isFalse);
    },
  );

  patrolWidgetTest('tapping dark persists and selects dark', ($) async {
    final repository = _FakeRepository();
    await _pump($, repository);
    await $(#settings.theme_mode.dark).tap();
    expect(_isSelected($, ThemeMode.dark), isTrue);
    expect(_isSelected($, ThemeMode.system), isFalse);
  });

  patrolWidgetTest(
    'given the save fails, the selection stays and an error is shown',
    ($) async {
      await _pump($, _FakeRepository(failSaves: true));
      await $(#settings.theme_mode.light).tap();
      expect(_isSelected($, ThemeMode.system), isTrue);
      expect(
        $(
          SettingsKeys.failureBanner,
        ).$('Could not save your choice. Please try again.'),
        findsOneWidget,
      );
    },
  );

  patrolWidgetTest('tapping the already selected mode keeps it selected', (
    $,
  ) async {
    await _pump($, _FakeRepository());
    await $(#settings.theme_mode.system).tap();
    expect(_isSelected($, ThemeMode.system), isTrue);
  });

  patrolWidgetTest(
    'disposing the screen while still loading closes the bloc cleanly',
    ($) async {
      // Plain pumps: a progress indicator animates forever, so
      // pumpWidgetAndSettle would time out here.
      await $.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) =>
                SettingsBloc(_FakeRepository(neverLoads: true))
                  ..add(const SettingsStarted()),
            child: const SettingsScreen(),
          ),
        ),
      );
      await $.pump();
      expect($(CircularProgressIndicator), findsOneWidget);
      await $.pumpWidget(const SizedBox.shrink());
      await $.pump();
      // No error, no pending timer: the lifecycle case "dispose during load".
    },
  );
}
