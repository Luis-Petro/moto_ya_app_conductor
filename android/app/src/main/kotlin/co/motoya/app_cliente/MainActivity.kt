package co.motoya.app_cliente

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        crearCanalAltaImportancia()
    }

    /**
     * Crea el canal de notificaciones de alta importancia. Debe coincidir con el
     * id que usa el backend (AndroidNotification.setChannelId) y con el
     * default_notification_channel_id del manifest; si no existe un canal HIGH,
     * Android entrega las push como "silenciosas".
     */
    private fun crearCanalAltaImportancia() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val canal = NotificationChannel(
            "motoya_alta_importancia",
            "Pedidos y alertas",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Nuevos pedidos y avisos importantes de motoYa"
            enableVibration(true)
        }
        manager.createNotificationChannel(canal)
    }
}
