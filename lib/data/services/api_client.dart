import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';

import '../../config/env.dart';
import 'api_result.dart';
import 'dispositivo_service.dart';
import 'session_storage.dart';

/// Cliente HTTP central. Apunta a la base `/Api`, adjunta el JWT en cada
/// petición autenticada, normaliza errores a [Failure] y centraliza el manejo
/// de 401 (sesión expirada → logout).
class ApiClient {
  ApiClient(this._session, {Dio? dio, DispositivoService? dispositivo})
    : _dispositivo = dispositivo,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              // No lanzamos en 4xx/5xx: lo convertimos a Failure nosotros.
              validateStatus: (s) => s != null && s < 500,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final sesion = await _session.leer();
          if (sesion != null) {
            options.headers['Authorization'] = 'Bearer ${sesion.token}';
          }
          // Equipo y versión, en cabecera y no en el cuerpo: si fueran cuerpo
          // habría que tocar los cinco endpoints que lo necesitan y sus records
          // en el servidor; aquí es un sitio y ninguna llamada cambia. El
          // servidor las trata como opcionales.
          await _adjuntarDispositivo(options);
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SessionStorage _session;
  final DispositivoService? _dispositivo;

  /// Nunca deja caer la petición: esto es contexto de soporte, no autenticación.
  ///
  /// El saneado va aquí además de en el servicio, y no es duplicado inútil:
  /// `dart:io` rechaza cualquier byte fuera de ASCII en una cabecera y lo hace
  /// **dentro del adaptador**, fuera del alcance de este try. El resultado es un
  /// "error de red" con la petición sin salir del teléfono — es decir, la app
  /// entera caída por un dato de soporte. Que ese valor sea imposible de
  /// construir mal es más barato que volver a diagnosticarlo.
  Future<void> _adjuntarDispositivo(RequestOptions options) async {
    final dispositivo = _dispositivo;
    if (dispositivo == null) return;
    try {
      options.headers['X-Dispositivo-Id'] = DispositivoService.soloAscii(
        await dispositivo.id(),
      );
      options.headers['X-Dispositivo'] = DispositivoService.soloAscii(
        await dispositivo.descripcion(),
      );
    } catch (e) {
      debugPrint('ApiClient: sin cabeceras de dispositivo ($e)');
    }
  }

  /// Invocado cuando una petición autenticada recibe 401: la app limpia sesión
  /// y redirige al acceso.
  void Function()? onUnauthorized;

  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parse,
  }) {
    return _send<T>(() => _dio.get(path, queryParameters: query), parse);
  }

  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    T Function(dynamic data)? parse,
  }) {
    return _send<T>(() => _dio.post(path, data: body), parse);
  }

  Future<Result<T>> put<T>(
    String path, {
    Object? body,
    T Function(dynamic data)? parse,
  }) {
    return _send<T>(() => _dio.put(path, data: body), parse);
  }

  Future<Result<T>> patch<T>(
    String path, {
    Object? body,
    T Function(dynamic data)? parse,
  }) {
    return _send<T>(() => _dio.patch(path, data: body), parse);
  }

  Future<Result<T>> delete<T>(String path, {T Function(dynamic data)? parse}) {
    return _send<T>(() => _dio.delete(path), parse);
  }

  /// POST con `multipart/form-data` (crear pedido, evidencia, etc.).
  ///
  /// [onProgreso] recibe bytes enviados y total. Es opcional y por defecto nulo:
  /// el resto de subidas no cambia de comportamiento. Dio informa `total` en `-1`
  /// cuando no lo conoce, y ese caso hay que dejarlo pasar tal cual — inventar un
  /// porcentaje es peor que no dar ninguno.
  Future<Result<T>> postMultipart<T>(
    String path, {
    required Map<String, dynamic> fields,
    T Function(dynamic data)? parse,
    void Function(int enviados, int total)? onProgreso,
  }) {
    final form = FormData();
    fields.forEach((key, value) {
      if (value == null) return;
      if (value is MultipartFile) {
        form.files.add(MapEntry(key, value));
      } else {
        form.fields.add(MapEntry(key, value.toString()));
      }
    });
    return _send<T>(
      () => _dio.post(path, data: form, onSendProgress: onProgreso),
      parse,
    );
  }

  Future<Result<T>> _send<T>(
    Future<Response> Function() request,
    T Function(dynamic data)? parse,
  ) async {
    try {
      final res = await request();
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        final data = parse != null ? parse(res.data) : res.data as T;
        return Ok<T>(data);
      }
      // Un 401 de /auth/* es un fallo de credenciales/código (esperado en el
      // flujo de acceso), no una sesión expirada: dispararía un logout+redirect
      // a mitad del onboarding (pantalla en blanco al equivocarse en el OTP).
      if (code == 401 && !res.requestOptions.path.startsWith('/auth/')) {
        onUnauthorized?.call();
      }
      return Err<T>(_failureFromResponse(res));
    } on DioException catch (e) {
      return Err<T>(_failureFromDio(e));
    } catch (e) {
      return Err<T>(
        Failure('Ocurrió un error inesperado.', kind: FailureKind.unknown),
      );
    }
  }

  Failure _failureFromResponse(Response res) {
    final code = res.statusCode;
    final msg =
        _extractMessage(res.data) ??
        switch (code) {
          400 => 'Datos inválidos. Revisa la información.',
          401 => 'Tu sesión expiró. Inicia sesión de nuevo.',
          403 => 'No tienes permiso para esta acción.',
          404 => 'No se encontró el recurso.',
          409 => 'La operación ya no es válida. Intenta de nuevo.',
          _ => 'No pudimos completar la solicitud.',
        };
    final kind = switch (code) {
      400 => FailureKind.validation,
      401 => FailureKind.unauthorized,
      404 => FailureKind.notFound,
      _ => FailureKind.server,
    };
    return Failure(msg, statusCode: code, codigo: _extractCodigo(res.data), kind: kind);
  }

  Failure _failureFromDio(DioException e) {
    // El servidor contestó (hoy, un 5xx: `validateStatus` deja pasar el 4xx sin
    // lanzar). Eso no es un fallo de red y no puede perder su código: la pantalla
    // decide qué ofrecer a partir de él.
    final res = e.response;
    if (res != null) return _failureFromResponse(res);

    final isTimeout =
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
    if (isTimeout) {
      return const Failure(
        'La conexión tardó demasiado. Reintenta.',
        kind: FailureKind.network,
      );
    }
    if (e.type == DioExceptionType.connectionError) {
      return const Failure(
        'Sin conexión. Verifica tu internet.',
        kind: FailureKind.network,
      );
    }
    // Sin respuesta y sin tipo reconocible (`unknown`: DNS, TLS, la red que se
    // cae a mitad). "Error de red." es cierto y no le dice nada a nadie; era el
    // texto de la pantalla que un conductor reportó como "no me deja abrir el
    // pedido".
    return const Failure(
      'No pudimos conectar con el servidor. Revisa tu conexión e intenta de nuevo.',
      kind: FailureKind.network,
    );
  }

  /// La marca del caso, si el servidor la mandó. Nula en casi todas las respuestas.
  String? _extractCodigo(dynamic data) {
    if (data is Map) {
      final c = data['codigo'];
      if (c is String && c.trim().isNotEmpty) return c;
    }
    return null;
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) {
      final m = data['message'] ?? data['error'] ?? data['detail'];
      if (m is String && m.trim().isNotEmpty) return m;
    }
    return null;
  }
}
