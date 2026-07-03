package co.motoya.app_cliente

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

/**
 * Application propia para crear el canal de notificaciones lo antes posible
 * (al arrancar el proceso, no solo al abrir la MainActivity).
 *
 * IMPORTANTE — inmutabilidad de canales: un NotificationChannel fija su
 * importancia/sonido en su PRIMERA creación; llamadas posteriores con el mismo
 * id no pueden subir la importancia (Android las ignora). Por eso el id se
 * versiona (`_v2`): así los dispositivos que tenían el canal viejo congelado en
 * importancia baja obtienen un canal nuevo en IMPORTANCE_HIGH. Además borramos
 * el canal viejo para no dejarlo huérfano en los Ajustes del sistema.
 */
class MotoyaApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        crearCanalAltaImportancia()
    }

    private fun crearCanalAltaImportancia() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        // Limpia el canal antiguo (posiblemente congelado en importancia baja).
        manager.deleteNotificationChannel(CANAL_ANTIGUO)
        val canal = NotificationChannel(
            CANAL_ALTA_IMPORTANCIA,
            "Pedidos y alertas",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Nuevos pedidos y avisos importantes de motoYa"
            enableVibration(true)
        }
        manager.createNotificationChannel(canal)
    }

    companion object {
        /**
         * Debe coincidir con `default_notification_channel_id` del manifest y con
         * el channelId del backend (PushNotificationService).
         */
        const val CANAL_ALTA_IMPORTANCIA = "motoya_alta_importancia_v2"
        private const val CANAL_ANTIGUO = "motoya_alta_importancia"
    }
}
