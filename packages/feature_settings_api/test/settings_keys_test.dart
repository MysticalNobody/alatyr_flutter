import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'theme mode tile keys are distinct ValueKey<String>s in the settings namespace',
    () {
      final keys = ThemeMode.values.map(SettingsKeys.themeModeTile).toList();
      expect(keys.toSet(), hasLength(ThemeMode.values.length));
      for (final key in keys) {
        expect(key, isA<ValueKey<String>>());
        expect(
          (key as ValueKey<String>).value,
          startsWith('settings.theme_mode.'),
        );
      }
    },
  );

  test(
    'dark tile key is the documented literal (patrol `#` selector form)',
    () {
      expect(
        SettingsKeys.themeModeTile(ThemeMode.dark),
        const ValueKey<String>('settings.theme_mode.dark'),
      );
    },
  );

  test('screen and error keys live in the settings namespace', () {
    expect(SettingsKeys.screen, const ValueKey<String>('settings.screen'));
    expect(
      SettingsKeys.failureBanner,
      const ValueKey<String>('settings.failure'),
    );
  });

  test('route path and name are the documented literals', () {
    expect(SettingsRoutes.path, '/settings');
    expect(SettingsRoutes.name, 'settings');
  });
}
