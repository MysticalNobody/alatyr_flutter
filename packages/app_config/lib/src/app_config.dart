import 'package:app_core/app_core.dart';

enum AppEnv { dev, staging, prod }

final class AppConfig {
  const AppConfig({required this.env, required this.apiBaseUrl});

  final AppEnv env;
  final Uri apiBaseUrl;

  static Result<AppConfig> parse({
    required String env,
    required String apiBaseUrl,
  }) {
    final parsedEnv = AppEnv.values.where((e) => e.name == env).firstOrNull;
    if (parsedEnv == null) {
      return Err(
        AppFailure(
          code: 'config.invalid-env',
          message:
              'APP_ENV must be one of ${AppEnv.values.map((e) => e.name)}, got "$env"',
        ),
      );
    }
    final url = Uri.tryParse(apiBaseUrl);
    if (url == null ||
        !url.isAbsolute ||
        (url.scheme != 'http' && url.scheme != 'https') ||
        url.host.isEmpty) {
      return Err(
        AppFailure(
          code: 'config.invalid-url',
          message:
              'API_BASE_URL must be an absolute http(s) URL, got "$apiBaseUrl"',
        ),
      );
    }
    return Ok(AppConfig(env: parsedEnv, apiBaseUrl: url));
  }

  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://template.invalid',
    );
    return parse(env: env, apiBaseUrl: apiBaseUrl).fold(
      ok: (config) => config,
      err: (f) => throw StateError('Invalid build configuration: $f'),
    );
  }
}
