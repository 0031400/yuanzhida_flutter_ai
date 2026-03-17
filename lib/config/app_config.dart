class AppConfig {
  AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'ANSWERLY_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
