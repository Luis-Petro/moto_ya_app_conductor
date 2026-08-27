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

  /// `true` solo cuando esta build habla con la API de **producción**.
  ///
  /// De aquí sale la marca de entorno del encabezado, y se **deriva** en vez de
  /// declararse: una bandera aparte (`ES_PRUEBAS=true`) se puede quedar apagada
  /// mientras la URL sí cambió —o al revés—, y el resultado sería una app de
  /// pruebas que no se anuncia, que es justo el estado que la marca existe para
  /// impedir. La pregunta que importa es "¿con quién estoy hablando?", y aquí se
  /// contesta con el dato que la responde.
  ///
  /// La barra final se ignora: `…/Api` y `…/Api/` son el mismo backend, y que
  /// una difiera de la otra convertiría un descuido de tecleo en una app de
  /// producción anunciándose como de pruebas.
  static bool get esProduccion =>
      _sinBarraFinal(apiBaseUrl) == '$_defaultHost/Api';

  static String _sinBarraFinal(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

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

  /// Estilo de tiles de Geoapify.
  ///
  /// Antes era `positron`. Se cambió tras verlo en un celular: se pasaba de
  /// vacío. Sus etiquetas son gris claro sobre gris casi blanco y no se leen al
  /// sol —que es la condición normal de un conductor en moto— y borraba la
  /// plaza, que es *el* punto de referencia del municipio.
  ///
  /// `klokantech-basic` mantiene contenido y contraste sin ser el ruido de
  /// `osm-carto`. Debe ser el mismo en las dos apps: el conductor y el cliente
  /// miran el mismo pedido.
  static const String tileStyle = String.fromEnvironment(
    'TILE_STYLE',
    defaultValue: 'klokantech-basic',
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

  /// `true` cuando las rutas que dibuja la app las calculó Geoapify.
  ///
  /// Lo decide el backend (`RUTEO_BASE_URL`), no la app, así que esto es una
  /// declaración: hoy es Geoapify y por eso el default es `true`. Existe porque
  /// la atribución no puede depender solo de quién sirve los tiles — con tiles
  /// de otra fuente y rutas de Geoapify, el crédito desaparecería sin que nadie
  /// lo notara, y sus términos lo exigen igual.
  static const bool ruteoGeoapify = bool.fromEnvironment(
    'RUTEO_GEOAPIFY',
    defaultValue: true,
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
