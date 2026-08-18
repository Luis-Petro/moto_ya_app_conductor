package com.zumbeo.conductor

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// El canal de notificaciones se crea en ZumbeoApplication.onCreate (arranque del
// proceso), no aquí, para que exista aunque la app no se haya abierto vía la UI.
//
// Lo que sí vive aquí es la lectura del estado REAL de los avisos en Android.
// «No me suena» tiene media docena de causas que desde fuera se ven idénticas, y
// las que más se repiten —No molestar activo, el canal silenciado a mano, la app
// restringida en segundo plano— **no las expone ningún plugin de Flutter**: hay
// que preguntárselas a los servicios del sistema. Sin esto, el diagnóstico del
// Perfil solo puede decir que el canal existe y tiene tono, que es exactamente lo
// que ya era cierto las veces que el conductor no oyó el pedido.
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_METODOS)
            .setMethodCallHandler { llamada, respuesta ->
                when (llamada.method) {
                    "estadoDeLosAvisos" -> respuesta.success(estadoDeLosAvisos())
                    "abrirAjustesDelCanal" -> {
                        abrirAjustesDelCanal()
                        respuesta.success(null)
                    }
                    else -> respuesta.notImplemented()
                }
            }
    }

    /**
     * Lo que Android piensa de nuestros avisos, no lo que la app cree haber
     * configurado. Cada clave responde a una causa distinta de silencio, y la
     * app las traduce a una frase accionable para el conductor.
     *
     * Todo va con respaldo: una capa de fabricante que devuelva null en cualquier
     * servicio no puede dejar sin diagnóstico al resto.
     */
    private fun estadoDeLosAvisos(): Map<String, Any?> {
        val notificaciones = getSystemService(NotificationManager::class.java)
        val canal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificaciones?.getNotificationChannel(ZumbeoApplication.CANAL_OFERTAS)
        } else {
            null
        }
        val energia = getSystemService(PowerManager::class.java)
        val actividad = getSystemService(ActivityManager::class.java)

        return mapOf(
            // El filtro de interrupciones: No molestar, modo dormir, modo
            // conducción y los horarios automáticos acaban todos aquí. Es la
            // causa que ningún permiso de la app puede sortear y la que más veces
            // explica un teléfono mudo con todo "bien" configurado.
            "filtroDeInterrupciones" to filtroDeInterrupciones(notificaciones),
            "puedeSaltarNoMolestar" to (canal?.canBypassDnd() ?: false),
            "canalExiste" to (canal != null),
            "canalImportancia" to (canal?.importance ?: -1),
            // Importancia 0 = el conductor silenció el canal a mano en los
            // Ajustes. Es reversible en dos toques, pero solo si alguien se lo
            // dice: desde la app se ve igual que un push que nunca llegó.
            "canalSilenciado" to (canal != null &&
                canal.importance == NotificationManager.IMPORTANCE_NONE),
            // `areNotificationsEnabled` es de API 24 y el minSdk es 23: por
            // debajo no existe la pregunta, y el plugin de Flutter ya cubre el
            // permiso de POST_NOTIFICATIONS por su cuenta.
            "avisosActivados" to (
                Build.VERSION.SDK_INT < Build.VERSION_CODES.N ||
                    notificaciones?.areNotificationsEnabled() != false
                ),
            // "Restringir uso de batería" (Android 9+): el sistema deja de
            // entregar en segundo plano. Es un ajuste distinto de la optimización
            // de batería y bastante más agresivo; muchas capas de fabricante lo
            // encienden solas cuando la app pasa días sin abrirse.
            "restringidaEnSegundoPlano" to (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                    actividad?.isBackgroundRestricted == true
                ),
            "exentaDeOptimizacionDeBateria" to
                (energia?.isIgnoringBatteryOptimizations(packageName) ?: false),
        )
    }

    /** Nombre del filtro, ya traducido: el número no le dice nada a nadie. */
    private fun filtroDeInterrupciones(gestor: NotificationManager?): String =
        when (gestor?.currentInterruptionFilter) {
            NotificationManager.INTERRUPTION_FILTER_ALL -> "todo"
            NotificationManager.INTERRUPTION_FILTER_PRIORITY -> "solo prioritarias"
            NotificationManager.INTERRUPTION_FILTER_ALARMS -> "solo alarmas"
            NotificationManager.INTERRUPTION_FILTER_NONE -> "silencio total"
            else -> "desconocido"
        }

    /**
     * Abre los ajustes **del canal de ofertas**, no los de la app.
     *
     * Es la diferencia entre "ve a Ajustes, busca la app, entra en
     * notificaciones, busca Pedidos entrantes" y una pantalla ya abierta en el
     * sitio. Ahí el conductor sube la importancia, activa el sonido o permite
     * saltarse No molestar — cosas que la app no puede hacer por él porque son
     * suyas por diseño de Android.
     */
    private fun abrirAjustesDelCanal() {
        val delCanal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, ZumbeoApplication.CANAL_OFERTAS)
        } else {
            null
        }
        val deLaApp = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", packageName, null))
        // El respaldo no es cosmético: hay capas de fabricante que no resuelven
        // la pantalla del canal, y abrir nada dejaría al conductor con el
        // problema nombrado y sin la salida.
        for (intento in listOfNotNull(delCanal, deLaApp)) {
            try {
                startActivity(intento)
                return
            } catch (e: Exception) {
                Log.w(TAG, "No se pudo abrir ${intento.action}: ${e.message}")
            }
        }
    }

    private companion object {
        /** Debe coincidir con `NotificacionLocalService._canalDePlataforma`. */
        const val CANAL_METODOS = "zumbeo/avisos"
        const val TAG = "MainActivity"
    }
}
