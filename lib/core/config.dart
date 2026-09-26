// DDE-Mart driver app — static config (original).

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// Audience checked against GET /app-config min_versions.
  static const audience = 'driver';

  static const appName = 'DDE Driver';
}
