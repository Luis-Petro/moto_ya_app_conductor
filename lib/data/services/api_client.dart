import 'package:dio/dio.dart';

import '../../config/env.dart';
import 'api_result.dart';
import 'session_storage.dart';

/// Cliente HTTP central. Apunta a la base `/Api`, adjunta el JWT en cada
/// petición autenticada, normaliza errores a [Failure] y centraliza el manejo
/// de 401 (sesión expirada → logout).
class ApiClient {
  ApiClient(this._session, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              // No lanzamos en 4xx/5xx: lo convertimos a Failure nosotros.
              validateStatus: (s) => s != null && s < 500,
            )) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final sesion = await _session.leer();
          if (sesion != null) {
            options.headers['Authorization'] = 'Bearer ${sesion.token}';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SessionStorage _session;

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
  Future<Result<T>> postMultipart<T>(
    String path, {
    required Map<String, dynamic> fields,
    T Function(dynamic data)? parse,
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
    return _send<T>(() => _dio.post(path, data: form), parse);
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
      if (code == 401) {
        onUnauthorized?.call();
      }
      return Err<T>(_failureFromResponse(res));
    } on DioException catch (e) {
      return Err<T>(_failureFromDio(e));
    } catch (e) {
      return Err<T>(Failure('Ocurrió un error inesperado.', kind: FailureKind.unknown));
    }
  }

  Failure _failureFromResponse(Response res) {
    final code = res.statusCode;
    final msg = _extractMessage(res.data) ??
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
    return Failure(msg, statusCode: code, kind: kind);
  }

  Failure _failureFromDio(DioException e) {
    final isTimeout = e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
    if (isTimeout) {
      return const Failure('La conexión tardó demasiado. Reintenta.',
          kind: FailureKind.network);
    }
    if (e.type == DioExceptionType.connectionError) {
      return const Failure('Sin conexión. Verifica tu internet.',
          kind: FailureKind.network);
    }
    return Failure(_extractMessage(e.response?.data) ?? 'Error de red.',
        statusCode: e.response?.statusCode, kind: FailureKind.network);
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) {
      final m = data['message'] ?? data['error'] ?? data['detail'];
      if (m is String && m.trim().isNotEmpty) return m;
    }
    return null;
  }
}
