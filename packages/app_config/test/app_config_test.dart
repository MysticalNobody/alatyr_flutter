import 'package:app_config/app_config.dart';
import 'package:test/test.dart';

void main() {
  test('parse accepts valid env and https url', () {
    final r = AppConfig.parse(
      env: 'staging',
      apiBaseUrl: 'https://api.example.com',
    );
    expect(r.isOk, isTrue);
    final config = r.valueOrNull!;
    expect(config.env, AppEnv.staging);
    expect(config.apiBaseUrl, Uri.parse('https://api.example.com'));
  });

  test('parse rejects unknown env with stable code', () {
    final r = AppConfig.parse(env: 'qa', apiBaseUrl: 'https://api.example.com');
    expect(r.failureOrNull?.code, 'config.invalid-env');
  });

  test('parse rejects non-absolute url with stable code', () {
    final r = AppConfig.parse(env: 'dev', apiBaseUrl: 'not a url');
    expect(r.failureOrNull?.code, 'config.invalid-url');
  });

  test('parse rejects mailto scheme with stable code', () {
    final r = AppConfig.parse(
      env: 'dev',
      apiBaseUrl: 'mailto:someone@example.com',
    );
    expect(r.failureOrNull?.code, 'config.invalid-url');
  });

  test('parse rejects file scheme with stable code', () {
    final r = AppConfig.parse(env: 'dev', apiBaseUrl: 'file:///etc/passwd');
    expect(r.failureOrNull?.code, 'config.invalid-url');
  });

  test('fromEnvironment falls back to dev + template.invalid', () {
    final config = AppConfig.fromEnvironment();
    expect(config.env, AppEnv.dev);
    expect(config.apiBaseUrl.host, 'template.invalid');
  });
}
