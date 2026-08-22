import 'package:design_system/design_system.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import 'theme_mode_selector.dart';

/// The settings page. Expects a [SettingsBloc] above it (the module's route
/// provides one).
final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    key: SettingsKeys.screen,
    title: 'Settings',
    body: BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) => switch (state) {
        SettingsLoading() => const Center(child: CircularProgressIndicator()),
        SettingsReady(:final themeMode, :final lastFailure) =>
          ThemeModeSelector(
            selected: themeMode,
            failure: lastFailure,
            onChanged: (mode) => context.read<SettingsBloc>().add(
              SettingsThemeModeChanged(mode),
            ),
          ),
      },
    ),
  );
}
