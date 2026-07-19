enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
  });
  final AppEnvironment environment;
  final String apiBaseUrl;
  final String wsBaseUrl;
  static AppConfig fromEnvironment() {
    const name = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'development',
    );
    final environment = AppEnvironment.values.firstWhere(
      (value) => value.name == name,
      orElse: () => AppEnvironment.development,
    );
    const configuredApi = String.fromEnvironment('API_BASE_URL');
    const configuredWs = String.fromEnvironment('WS_BASE_URL');
    return AppConfig(
      environment: environment,
      apiBaseUrl:
          configuredApi.isEmpty ? 'http://10.0.2.2:8080' : configuredApi,
      wsBaseUrl: configuredWs.isEmpty ? 'ws://10.0.2.2:8080' : configuredWs,
    );
  }
}
