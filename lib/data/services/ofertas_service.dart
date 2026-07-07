import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../config/env.dart';
import '../../domain/models/oferta.dart';
import 'session_storage.dart';

/// Canal STOMP personal de ofertas del conductor. Se conecta a `/ws-tracking`
/// autenticando el CONNECT con el JWT y se suscribe a la cola personal
/// `/user/queue/ofertas`, por la que el backend empuja el ciclo de vida de la
/// oferta en tiempo real (`PEDIDO_NUEVO`, `OFERTA_EXPIRADA`, `PEDIDO_TOMADO`,
/// `PEDIDO_CANCELADO`), redundante al push FCM y al sondeo REST.
///
/// A diferencia de [TrackingService] (conexión efímera ligada a la pantalla de
/// un pedido), esta conexión es de larga duración: vive mientras el conductor
/// está en línea en el Inicio. Por eso es un servicio aparte, para no chocar con
/// el ciclo de vida connect/disconnect del tracking.
class OfertasService {
  OfertasService(this._session);

  final SessionStorage _session;

  StompClient? _client;
  StreamController<EventoOferta>? _controller;

  /// `true` mientras la conexión STOMP está activa (el sondeo se relaja a
  /// intervalo largo cuando lo está; vuelve al corto si se cae).
  bool get conectado => _client?.connected ?? false;

  /// Stream tipado de eventos de oferta. Broadcast: admite varios suscriptores
  /// (Inicio y la tarjeta de pedido entrante).
  Stream<EventoOferta> connect() {
    if (_controller != null) return _controller!.stream;
    final controller = StreamController<EventoOferta>.broadcast();
    _controller = controller;
    _activar(); // resuelve el token y activa el cliente (async, best-effort)
    return controller.stream;
  }

  Future<void> _activar() async {
    final headers = await _authHeaders();
    if (_controller == null) return; // desconectado mientras se leía la sesión
    _client = StompClient(
      config: StompConfig.sockJS(
        url: Env.wsTrackingUrl,
        reconnectDelay: const Duration(seconds: 4),
        onConnect: _onConnect,
        // El JWT viaja como header nativo del frame CONNECT; el backend fija el
        // Principal de la sesión para enrutar `/user/queue/**`.
        stompConnectHeaders: headers,
        onWebSocketError: (_) {/* reconnectDelay reintenta */},
        onStompError: (_) {},
      ),
    );
    _client!.activate();
  }

  Future<Map<String, String>> _authHeaders() async {
    final sesion = await _session.leer();
    if (sesion == null) return const {};
    return {'Authorization': 'Bearer ${sesion.token}'};
  }

  void _onConnect(StompFrame frame) {
    _client?.subscribe(
      destination: '/user/queue/ofertas',
      callback: (StompFrame f) {
        final body = f.body;
        if (body == null || body.isEmpty) return;
        try {
          final json = jsonDecode(body);
          if (json is Map<String, dynamic>) {
            final raw = json['pedidoId'];
            final id = raw is int ? raw : int.tryParse('$raw');
            if (id != null) {
              _controller?.add(EventoOferta(
                  TipoEventoOferta.fromWire(json['tipo'] as String?), id));
            }
          }
        } catch (_) {/* mensaje malformado: ignorar */}
      },
    );
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    _controller?.close();
    _controller = null;
  }
}
