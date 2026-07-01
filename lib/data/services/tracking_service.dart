import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../config/env.dart';
import '../../domain/models/evento_tracking.dart';
import 'session_storage.dart';

/// Canal de tracking en tiempo real (STOMP sobre SockJS). Se conecta a
/// `/ws-tracking` y se suscribe a `/topic/pedido/{id}`. Reconecta solo mientras
/// haya una suscripción activa; el consumidor debe llamar a [disconnect] al
/// abandonar la pantalla (limpieza de recursos — anti-patrón: dejar listeners
/// zombies).
class TrackingService {
  TrackingService(this._session);

  final SessionStorage _session;

  StompClient? _client;
  StreamController<EventoTracking>? _controller;
  int? _pedidoId;

  /// Stream de eventos del pedido suscrito. Broadcast para múltiples oyentes.
  Stream<EventoTracking> connect(int pedidoId) {
    disconnect();
    _pedidoId = pedidoId;
    final controller = StreamController<EventoTracking>.broadcast();
    _controller = controller;

    _client = StompClient(
      config: StompConfig.sockJS(
        url: Env.wsTrackingUrl,
        reconnectDelay: const Duration(seconds: 4),
        onConnect: _onConnect,
        beforeConnect: () async {
          final sesion = await _session.leer();
          if (sesion != null) {
            // Header opcional por si el endpoint exige token en el CONNECT.
          }
        },
        onWebSocketError: (_) {/* el reconnectDelay reintenta */},
        onStompError: (_) {},
      ),
    );
    _client!.activate();
    return controller.stream;
  }

  void _onConnect(StompFrame frame) {
    final id = _pedidoId;
    if (id == null) return;
    _client?.subscribe(
      destination: '/topic/pedido/$id',
      callback: (StompFrame f) {
        final body = f.body;
        if (body == null || body.isEmpty) return;
        try {
          final json = jsonDecode(body);
          if (json is Map<String, dynamic>) {
            final evento = EventoTracking.fromJson(json);
            if (evento != null) _controller?.add(evento);
          }
        } catch (_) {/* mensaje malformado: ignorar */}
      },
    );
  }

  /// Publica la posición del conductor por STOMP hacia el canal del pedido
  /// activo. Best-effort: si aún no hay conexión, se ignora (el reporte REST
  /// `PUT /conductores/me/ubicacion` mantiene la posición como respaldo).
  void publicarPosicion(int pedidoId, double lat, double lng) {
    final client = _client;
    if (client == null || !client.connected) return;
    try {
      client.send(
        destination: '/app/pedido/$pedidoId/posicion',
        body: jsonEncode({'lat': lat, 'lng': lng}),
      );
    } catch (_) {/* canal no disponible: se reintenta en el próximo punto */}
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    _controller?.close();
    _controller = null;
    _pedidoId = null;
  }
}
