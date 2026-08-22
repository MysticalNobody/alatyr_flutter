import 'package:app_config/app_config.dart';
import 'package:app_core/app_core.dart';
import 'package:data_local/data_local.dart';
import 'package:data_secure/data_secure.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:go_router/go_router.dart';

/// The composition root: every implementation is constructed HERE, by hand,
/// and handed down through constructors (ADR: manual DI). Feature modules
/// receive only what they declare; the app assembles the router from the
/// routes they contribute.
final class AppDependencies {
  AppDependencies({
    required this.config,
    required this.logger,
    required this.database,
    required this.secureStore,
  }) : settings = createSettingsModule(
         keyValueDao: database.keyValueDao,
         logger: logger,
       );

  /// Production wiring: real config from dart-defines, console logging, the
  /// on-device database and the platform keychain.
  factory AppDependencies.production() => AppDependencies(
    config: AppConfig.fromEnvironment(),
    logger: const ConsoleLogger(),
    database: AppDatabase.open(name: 'alatyr_starter'),
    secureStore: const FlutterSecureStore.platform(),
  );

  final AppConfig config;
  final AppLogger logger;
  final AppDatabase database;

  /// Where runtime secrets go (hard invariant 4). No feature needs it yet;
  /// the first one that does receives it through its module factory.
  final SecureStore secureStore;

  final SettingsModule settings;

  GoRouter buildRouter() => GoRouter(
    initialLocation: SettingsRoutes.path,
    routes: [...settings.routes],
  );

  Future<void> dispose() => database.close();
}
