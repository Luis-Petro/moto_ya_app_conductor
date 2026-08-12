package com.zumbeo.conductor

import io.flutter.embedding.android.FlutterActivity

// El canal de notificaciones se crea en ZumbeoApplication.onCreate (arranque del
// proceso), no aquí, para que exista aunque la app no se haya abierto vía la UI.
class MainActivity : FlutterActivity()
