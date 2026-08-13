/// Configuración por entorno. La URL base y las claves externas se inyectan en
/// tiempo de compilación con `--dart-define` y nunca se hardcodean en la UI.
///
/// Ejemplo:
///   flutter run --dart-define=API_BASE_URL=https://api.zumbeo.com/Api \
///               --dart-define=TILE_API_KEY=tu-clave-de-geoapify
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

  /// Estilo de tiles de Geoapify. `positron` es gris casi blanco y con muy
  /// pocos POI propios: el mapa no compite con lo que el conductor sí tiene que
  /// leer encima —recogida, entrega, la ruta y su propia posición—, que va todo
  /// en naranja de marca. Debe ser el mismo estilo que la app cliente: son la
  /// misma marca y el conductor y el cliente miran el mismo pedido.
  static const String tileStyle = String.fromEnvironment(
    'TILE_STYLE',
    defaultValue: 'positron',
  );

  /// Clave de Geoapify. Se inyecta en el build desde el secret `TILE_API_KEY`;
  /// no vive en el repo.
  ///
  /// Queda embebida en el APK y es extraíble, como cualquier clave de cliente.
  /// El riesgo está acotado porque el plan gratuito **no cobra por exceso**: no
  /// hay factura sorpresa posible. Lo que sí puede hacer quien la saque es
  /// quemarnos la cuota del día — y los límites de Geoapify son *soft*: si el
  /// consumo se pasa de forma sostenida escriben pidiendo un plan mayor y se
  /// reservan bloquear la cuenta si se ignora. O sea que el daño de una fuga es
  /// operativo, no económico.
  static const String tileApiKey = String.fromEnvironment('TILE_API_KEY');

  /// Plantilla de tiles completa. Salida de emergencia: permite apuntar a otro
  /// proveedor —o a tiles propios en R2— sin tocar código. Gana sobre
  /// `TILE_API_KEY`.
  static const String _tileUrlOverride = String.fromEnvironment('TILE_URL');

  /// Plantilla de tiles que consume `osmTileLayer()`.
  ///
  /// Precedencia: `TILE_URL` → Geoapify con `TILE_API_KEY` → tiles de
  /// `openstreetmap.org`.
  ///
  /// Ese último caso es **solo para desarrollo**. La política de uso de OSM
  /// prohíbe el uso intensivo de sus servidores —los paga la comunidad con
  /// donaciones— y bloquea por User-Agent sin avisar, lo que dejaría el mapa
  /// gris en todas las instalaciones a la vez y sin error visible. Aun así es
  /// el respaldo, y a propósito: si un build manual olvida la clave, el mapa se
  /// ve. Un respaldo que dejara el mapa en blanco convertiría un olvido de
  /// configuración en un fallo que parece del mapa.
  static String get tileUrl {
    if (_tileUrlOverride.isNotEmpty) return _tileUrlOverride;
    if (tileApiKey.isNotEmpty) {
      return 'https://maps.geoapify.com/v1/tile/$tileStyle/{z}/{x}/{y}.png'
          '?apiKey=$tileApiKey';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  /// `true` cuando los tiles los sirve Geoapify. Sus términos de uso gratuito
  /// exigen acreditarlo **además** de a OpenStreetMap, así que la atribución
  /// del mapa depende de esto.
  static bool get tilesGeoapify =>
      _tileUrlOverride.isEmpty && tileApiKey.isNotEmpty;

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
