/// Configuración por entorno. La URL base y las claves externas se inyectan en
/// tiempo de compilación con `--dart-define` y nunca se hardcodean en la UI.
///
/// Ejemplo:
///   flutter run --dart-define=API_BASE_URL=https://api.zumbeo.com/Api \
///               --dart-define=OSM_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png
class Env {
  const Env._();

  /// Host del backend desplegado (Dokploy). Sobreescribible por entorno.
  static const String _defaultHost =
      'https://api.zumbeo.com';

  /// Base de la API del backend Zumbeo (context-path `/Api`).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '$_defaultHost/Api',
  );

  /// Endpoint WebSocket/STOMP (SockJS) para tracking en vivo.
  static const String wsTrackingUrl = String.fromEnvironment(
    'WS_TRACKING_URL',
    defaultValue: '$_defaultHost/Api/ws-tracking',
  );

  /// Sitio público (la landing del apex). **No** es el panel administrativo:
  /// las páginas legales las abre un conductor, y un enlace a un host que dice
  /// "admin" parece un phishing. Es el mismo host de `PANEL_BASE_URL` en el
  /// backend, que conserva ese nombre por historia.
  static const String sitioBaseUrl = String.fromEnvironment(
    'SITIO_BASE_URL',
    defaultValue: 'https://zumbeo.com',
  );

  /// Términos y condiciones. Google Play exige declarar esta URL en la ficha, y
  /// tiene que ser alcanzable **desde dentro de la app**, no solo desde la web.
  /// Es donde está escrito que el conductor es independiente y cómo funciona la
  /// comisión, así que aquí importa más todavía que en la app cliente.
  static const String terminosUrl = '$sitioBaseUrl/terminos';

  /// Política de privacidad, también obligatoria en la ficha de Play.
  static const String privacidadUrl = '$sitioBaseUrl/privacidad';

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

  /// Habilita la integración con Firebase Cloud Messaging. Activo por defecto:
  /// si falta `google-services.json`/`GoogleService-Info.plist`, la
  /// inicialización falla con gracia (try/catch) y la app opera sin push (el
  /// Inicio sondea ofertas como respaldo). El backend además requiere
  /// `FCM_CREDENTIALS_PATH` para poder enviar.
  static const bool fcmEnabled = bool.fromEnvironment(
    'FCM_ENABLED',
    defaultValue: true,
  );
}
