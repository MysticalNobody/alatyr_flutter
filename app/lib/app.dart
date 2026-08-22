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
    builder: (context, snapshot) => MaterialApp.router(
      title: 'Alatyr Starter',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: snapshot.data,
      routerConfig: _router,
    ),
  );
}
