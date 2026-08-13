# Zumbeo — App Conductor

App móvil Flutter para el rol **CONDUCTOR** de la plataforma Zumbeo ("Tu pueblo, a un domicilio"). El conductor se pone en línea, recibe pedidos cercanos, acepta o contraoferta la tarifa, ejecuta la entrega paso a paso, cobra su ganancia neta y liquida la deuda de comisiones (Nequi/Bre‑B).

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
  --dart-define=TILE_API_KEY=<clave de Geoapify> \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<google-client-id> \
  --dart-define=FCM_ENABLED=false
```

`applicationId`: `com.zumbeo.conductor` (se instala junto a la app cliente). FCM está desactivado por defecto: la app arranca sin `google-services.json`.

### Tiles del mapa

Los datos son de OpenStreetMap, pero **quien los sirve no puede ser
`openstreetmap.org`**: su política de uso prohíbe el uso intensivo desde una app
distribuida y bloquea por User-Agent sin avisar, lo que dejaría el mapa gris en
todas las instalaciones a la vez.

En producción los sirve **Geoapify** (plan gratuito: 3.000 créditos/día, 0,25 por
tile, uso comercial permitido con atribución). La clave va en el secret
`TILE_API_KEY` del environment `prod` del workflow.

| Flag | Default | Uso |
|------|---------|-----|
| `TILE_API_KEY` | `''` | Clave de Geoapify. Sin ella el mapa cae a los tiles de OSM: vale para desarrollo, **no** para un release |
| `TILE_STYLE` | `positron` | Estilo de Geoapify. El mismo que la app cliente: son la misma marca |
| `TILE_URL` | `''` | Plantilla completa `{z}/{x}/{y}`. Salida de emergencia: otro proveedor o tiles propios en R2 sin tocar código. Gana sobre `TILE_API_KEY` |

Los tiles se guardan en disco 30 días (`MapTileCache`). Aquí pesa más que en la
app cliente: el mapa está abierto todo el domicilio, el municipio es siempre el
mismo y los datos los paga el conductor. Además, cada tile que sale de disco es
un crédito de la cuota diaria que no se gasta.

## Calidad

```bash
flutter analyze   # sin issues
flutter test      # 20/20
```

Especificación completa: `openspec/changes/app-conductor-flutter/`.
