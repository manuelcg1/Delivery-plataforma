enum AppEnvironment { development, staging, production }

class AppConfig {
  static const productionApiBaseUrl = 'https://api.cerka.site';
  static const productionRealtimeUrl = 'wss://api.cerka.site/api/v1/realtime';
  static const productionWsBaseUrl = 'wss://api.cerka.site';

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.realtimeUrl,
    required this.mapTileUrl,
  });
  final AppEnvironment environment;
  final String apiBaseUrl;
  final String realtimeUrl;
  final String mapTileUrl;
  static final defaultMapLatitude = double.parse(const String.fromEnvironment(
      'DEFAULT_MAP_LATITUDE',
      defaultValue: '-16.3989'));
  static final defaultMapLongitude = double.parse(const String.fromEnvironment(
      'DEFAULT_MAP_LONGITUDE',
      defaultValue: '-71.5350'));
  static final defaultMapZoom = double.parse(
      const String.fromEnvironment('DEFAULT_MAP_ZOOM', defaultValue: '15'));
  String get wsBaseUrl => realtimeUrl;
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
    const configuredRealtime = String.fromEnvironment('REALTIME_URL');
    const legacyWs = String.fromEnvironment('WS_BASE_URL');
    const configuredTiles = String.fromEnvironment('MAP_TILE_URL');
    final defaultApi = environment == AppEnvironment.production
        ? productionApiBaseUrl
        : 'http://10.0.2.2:8080';
    final defaultRealtime = environment == AppEnvironment.production
        ? productionRealtimeUrl
        : 'ws://10.0.2.2:8080/api/v1/realtime';
    final realtime = configuredRealtime.isNotEmpty
        ? configuredRealtime
        : legacyWs.isNotEmpty
            ? (legacyWs.endsWith('/api/v1/realtime')
                ? legacyWs
                : '$legacyWs/api/v1/realtime')
            : defaultRealtime;
    return AppConfig(
      environment: environment,
      apiBaseUrl: configuredApi.isEmpty ? defaultApi : configuredApi,
      realtimeUrl: realtime,
      mapTileUrl: configuredTiles.isEmpty
          ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
          : configuredTiles,
    );
  }
}
