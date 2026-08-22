import 'package:app_core/app_core.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';

/// Single-choice list of theme modes. Stateless: the selected mode and the
/// last failure come from the bloc state, taps go back as callbacks.
final class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({
    required this.selected,
    required this.onChanged,
    this.failure,
    super.key,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;
  final AppFailure? failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Public fields never promote; shadow it so `_message(failure)` sees a
    // non-nullable value (same idiom as AppChoiceTile.subtitle).
    final failure = this.failure;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              _message(failure),
              key: SettingsKeys.failureBanner,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        for (final mode in ThemeMode.values)
          AppChoiceTile(
            key: SettingsKeys.themeModeTile(mode),
            title: _label(mode),
            selected: mode == selected,
            onTap: () => onChanged(mode),
          ),
      ],
    );
  }

  static String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  static String _message(AppFailure failure) => switch (failure.code) {
    SettingsFailureCodes.load => 'Could not read your saved settings.',
    _ => 'Could not save your choice. Please try again.',
  };
}
