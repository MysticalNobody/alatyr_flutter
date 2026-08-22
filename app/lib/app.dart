import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'bootstrap/app_dependencies.dart';

/// Root widget: owns the router and drives [MaterialApp.themeMode] from the
/// settings feature through its api port.
final class App extends StatefulWidget {
  const App({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<App> createState() => _AppState();
}

final class _AppState extends State<App> {
  late final GoRouter _router = widget.dependencies.buildRouter();

  // Subscribed once: a new stream per build would resubscribe on every
  // rebuild and replay the current value each time.
  late final Stream<ThemeMode> _themeMode = widget.dependencies.settings.api
      .watchThemeMode();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ThemeMode>(
    stream: _themeMode,
    initialData: ThemeMode.system,
    builder: (context, snapshot) {
      // A stream error clears the data; without this the app would fall back
      // to system silently. The user-facing message is the settings feature's
      // job (its bloc surfaces the same failure), so this is only a log line.
      if (snapshot.hasError) {
        widget.dependencies.logger.warn(
          'settings: theme mode stream failed, using system',
          error: snapshot.error,
        );
      }
      return MaterialApp.router(
        title: 'Alatyr Starter',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: snapshot.data ?? ThemeMode.system,
        routerConfig: _router,
      );
    },
  );
}
