import 'package:flutter/widgets.dart';

import '../app.dart';
import 'app_dependencies.dart';

/// Process entry: binding, dependencies, run. [createDependencies] is the
/// test seam: the bootstrap smoke test runs this exact path with in-memory
/// dependencies; `main` uses production ones.
Future<void> bootstrap({
  AppDependencies Function() createDependencies = AppDependencies.production,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App(dependencies: createDependencies()));
}
