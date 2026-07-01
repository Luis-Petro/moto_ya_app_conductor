/// Configuración por entorno. La URL base y las claves externas se inyectan en
/// tiempo de compilación con `--dart-define` y nunca se hardcodean en la UI.
///
/// Ejemplo:
///   flutter run --dart-define=API_BASE_URL=https://api.motoya.co/Api \
///               --dart-define=OSM_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png
class Env {
  const Env._();

  /// Host del backend desplegado (Dokploy). Sobreescribible por entorno.
  static const String _defaultHost =
      'https://motoya-motoyabackend-bnisvv-62ac9d-149-130-180-30.sslip.io';

  /// Base de la API del backend motoYa (context-path `/Api`).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '$_defaultHost/Api',
  );

  /// Endpoint WebSocket/STOMP (SockJS) para tracking en vivo.
  static const String wsTrackingUrl = String.fromEnvironment(
    'WS_TRACKING_URL',
    defaultValue: '$_defaultHost/Api/ws-tracking',
  );

  /// Plantilla de tiles OpenStreetMap (configurable para producción).
  static const String osmTileUrl = String.fromEnvironment(
    'OSM_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// Client ID de Google para la verificación server-side del idToken.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// Habilita el botón de inicio de sesión con Apple (Open Question Q1).
  static const bool appleSignInEnabled = bool.fromEnvironment(
    'APPLE_SIGN_IN_ENABLED',
    defaultValue: false,
  );

  /// Habilita la integración con Firebase Cloud Messaging.
  static const bool fcmEnabled = bool.fromEnvironment(
    'FCM_ENABLED',
    defaultValue: false,
  );
}
