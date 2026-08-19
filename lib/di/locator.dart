import 'package:get_it/get_it.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/billetera_repository.dart';
import '../data/repositories/conductor_repository.dart';
import '../data/repositories/municipio_repository.dart';
import '../data/repositories/pedido_repository.dart';
import '../data/repositories/usuario_repository.dart';
import '../data/services/api_client.dart';
import '../data/services/app_version_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/feedback_service.dart';
import '../data/services/billetera_service.dart';
import '../data/services/conductor_service.dart';
import '../data/services/dispositivo_service.dart';
import '../data/services/location_service.dart';
import '../data/services/lugar_service.dart';
import '../data/services/municipio_service.dart';
import '../data/services/notificacion_local_service.dart';
import '../data/services/notificacion_service.dart';
import '../data/services/ofertas_service.dart';
import '../data/services/permisos_service.dart';
import '../data/services/pedido_service.dart';
import '../data/services/push_service.dart';
import '../data/services/session_storage.dart';
import '../data/services/social_auth_service.dart';
import '../data/services/tracking_service.dart';
import '../data/services/usuario_service.dart';
import '../ui/core/tab_activa.dart';

/// Contenedor de inyección de dependencias de la app conductor.
final GetIt locator = GetIt.instance;

void configurarDependencias() {
  // ── Infraestructura ──
  locator.registerLazySingleton(() => SessionStorage());
  locator.registerLazySingleton(() => DispositivoService());
  locator.registerLazySingleton(
      () => ApiClient(locator(), dispositivo: locator<DispositivoService>()));
  locator.registerLazySingleton(() => SocialAuthService());
  locator.registerLazySingleton(() => PushService());
  locator.registerLazySingleton(() => NotificacionLocalService());
  locator.registerLazySingleton(() => LocationService());
  locator.registerLazySingleton(() => PermisosService(
        locator<PushService>(),
        locator<NotificacionLocalService>(),
      ));
  locator.registerLazySingleton(() => TabActiva());

  // ── Services (acceso crudo a la API) ──
  locator.registerLazySingleton(() => AuthService(locator()));
  locator.registerLazySingleton(() => UsuarioService(locator()));
  locator.registerLazySingleton(() => ConductorService(locator()));
  locator.registerLazySingleton(() => PedidoService(locator()));
  locator.registerLazySingleton(() => BilleteraService(locator()));
  locator.registerLazySingleton(() => NotificacionService(locator()));
  locator.registerLazySingleton(() => TrackingService(locator()));
  locator.registerLazySingleton(() => OfertasService(locator()));
  locator.registerLazySingleton(() => MunicipioService(locator()));
  locator.registerLazySingleton(() => LugarService(locator()));
  locator.registerLazySingleton(() => FeedbackService(locator()));
  locator.registerLazySingleton(() => AppVersionService(locator()));

  // ── Repositories (fuente de verdad, modelos de dominio) ──
  locator.registerLazySingleton(() => AuthRepository(
        locator<AuthService>(),
        locator<SocialAuthService>(),
        locator<SessionStorage>(),
        locator<NotificacionService>(),
        locator<PushService>(),
        locator<TrackingService>(),
      ));
  locator.registerLazySingleton(() => UsuarioRepository(locator()));
  locator.registerLazySingleton(() => MunicipioRepository(locator()));
  locator.registerLazySingleton(() => ConductorRepository(locator()));
  locator.registerLazySingleton(() => PedidoRepository(locator()));
  locator.registerLazySingleton(() => BilleteraRepository(locator()));

  // El ApiClient redirige al acceso cuando una petición autenticada da 401.
  locator<ApiClient>().onUnauthorized = () {
    locator<AuthRepository>().sesionExpirada();
    locator<ConductorRepository>().limpiar();
  };
}
