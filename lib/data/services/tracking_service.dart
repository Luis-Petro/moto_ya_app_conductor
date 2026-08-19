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

  /// Token con el que se abrió el canal vigente. Sirve para detectar que la
  /// sesión cambió (otra cuenta entró en el mismo teléfono) y rehacer la
  /// conexión: el CONNECT lleva el token, así que un canal abierto con el
  /// anterior seguiría hablando en nombre de quien ya no está.
  String? _tokenDelCanal;

  /// Stream de eventos del pedido suscrito. Broadcast para múltiples oyentes.
  Stream<EventoTracking> connect(int pedidoId) {
    disconnect();
    _pedidoId = pedidoId;
    final controller = StreamController<EventoTracking>.broadcast();
    _controller = controller;
    _activar(controller); // resuelve la sesión y activa el cliente (async)
    return controller.stream;
  }

  /// Abre el canal, pero solo si hay sesión: el backend **rechaza el CONNECT sin
  /// token**, así que activar el cliente sin ella sería un reintento cada cuatro
  /// segundos contra un servidor que va a decir que no siempre.
  Future<void> _activar(StreamController<EventoTracking> controller) async {
    final sesion = await _session.leer();
    if (!identical(_controller, controller)) return; // se cerró mientras se leía
    final token = sesion?.token;
    if (token == null || token.isEmpty) {
      disconnect();
      return;
    }
    _tokenDelCanal = token;

    // El CONNECT se manda después de `beforeConnect`, así que basta con rellenar
    // este mapa ahí: el frame se construye con lo que tenga en ese momento. Y se
    // rellena en cada reconexión, no solo en la primera, que es lo que hace que
    // un token renovado entre solo.
    final headers = <String, String>{'Authorization': 'Bearer $token'};

    _client = StompClient(
      config: StompConfig.sockJS(
        url: Env.wsTrackingUrl,
        reconnectDelay: const Duration(seconds: 4),
        onConnect: _onConnect,
        stompConnectHeaders: headers,
        beforeConnect: () async {
          final sesion = await _session.leer();
          final token = sesion?.token;
          if (token != null && token.isNotEmpty) {
            headers['Authorization'] = 'Bearer $token';
            _tokenDelCanal = token;
          }
        },
        onWebSocketError: (_) {/* el reconnectDelay reintenta */},
        onStompError: (_) {},
      ),
    );
    _client!.activate();
  }

  /// Rehace el canal si la sesión ya no es la que lo abrió. Sin esto, cerrar
  /// sesión y entrar con otra cuenta dejaba vivo un canal autenticado como el
  /// usuario anterior hasta que alguien cambiara de pantalla.
  Future<void> revisarSesion() async {
    final id = _pedidoId;
    if (id == null) return;
    final sesion = await _session.leer();
    if (sesion?.token == _tokenDelCanal) return;
    if (sesion == null) {
      disconnect();
      return;
    }
    connect(id);
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
    _tokenDelCanal = null;
  }
}
