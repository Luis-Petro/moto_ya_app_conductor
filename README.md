# motoYa — App Conductor

App móvil Flutter para el rol **CONDUCTOR** de la plataforma motoYa ("Tu pueblo, a un domicilio"). El conductor se pone en línea, recibe pedidos cercanos, acepta o contraoferta la tarifa, ejecuta la entrega paso a paso, cobra su ganancia neta y liquida la deuda de comisiones (Nequi/Bre‑B).

Hermana de `app_cliente/` (rol CLIENTE) y `backend/` (Spring Boot). Consume la misma API (`/Api`) sin modificarla. Comparte el sistema de diseño de `app_cliente` (paleta naranja `#F2641E` + navy `#17293D`).

## Arquitectura

Capas (MVVM + Repository), según `flutter-apply-architecture-best-practices`:

- `lib/domain/models` — modelos de dominio puros (`Conductor`, `Billetera`, `Pedido`, …).
- `lib/data/{services,repositories,models}` — `ApiClient` (Dio + JWT), servicios por recurso, repositorios (fuente de verdad) y mappers JSON→dominio.
- `lib/ui/{core,features}` — tema/componentes núcleo y features (`inicio`, `pedido_entrante`, `pedido_activo`, `billetera`, `historial`, `perfil`, `alta_conductor`, `auth`).
- `lib/di/locator.dart` — inyección de dependencias (`get_it`). `lib/ui/router.dart` — `go_router` con guardas.

## Ejecutar

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://<host>/Api \
  --dart-define=WS_TRACKING_URL=https://<host>/Api/ws-tracking \
  --dart-define=OSM_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<google-client-id> \
  --dart-define=FCM_ENABLED=false
```

`applicationId`: `co.motoya.conductor` (se instala junto a la app cliente). FCM está desactivado por defecto: la app arranca sin `google-services.json`.

## Calidad

```bash
flutter analyze   # sin issues
flutter test      # 20/20
```

Especificación completa: `openspec/changes/app-conductor-flutter/`.
