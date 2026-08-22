import 'package:app_core/app_core.dart';
import 'package:data_local/data_local.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'bloc/settings_bloc.dart';
import 'bloc/settings_event.dart';
import 'drift_settings_repository.dart';
import 'settings_api_impl.dart';
import 'ui/settings_screen.dart';

/// What the settings feature hands to the app: routes to mount and the api
/// other parts of the app talk to.
final class SettingsModule {
  const SettingsModule({required this.routes, required this.api});

  final List<RouteBase> routes;
  final SettingsApi api;
}

/// The feature's single entry point. `app/` calls this from its composition
/// root with the dependencies it constructed; nothing else in the package
/// is public.
SettingsModule createSettingsModule({
  required KeyValueDao keyValueDao,
  AppLogger logger = const NoopLogger(),
}) {
  final repository = DriftSettingsRepository(keyValueDao, logger: logger);
  return SettingsModule(
    routes: [
      GoRoute(
        path: SettingsRoutes.path,
        name: SettingsRoutes.name,
        builder: (context, state) => BlocProvider(
          create: (_) => SettingsBloc(repository)..add(const SettingsStarted()),
          child: const SettingsScreen(),
        ),
      ),
    ],
    api: RepositorySettingsApi(repository),
  );
}
