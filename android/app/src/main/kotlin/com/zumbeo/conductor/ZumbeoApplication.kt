package com.zumbeo.conductor

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

/**
 * Application propia para crear los canales de notificación lo antes posible
 * (al arrancar el proceso, no solo al abrir la MainActivity).
 *
 * IMPORTANTE — inmutabilidad de canales: un NotificationChannel fija su
 * importancia y su SONIDO en su PRIMERA creación; las llamadas posteriores con
 * el mismo id se ignoran. Por eso los ids van versionados: cambiar el tono de un
 * canal existente es imposible, hay que crear otro. Los canales anteriores se
 * borran para no dejarlos huérfanos en los Ajustes del sistema.
 *
 * Hay DOS canales de aviso, no uno: con un canal único, un conductor harto de
 * los avisos generales silenciaría también los pedidos, y ese es el único
 * silencio que la app no se puede permitir.
 *
 * El tercer canal —el de la notificación permanente de "en línea"— NO se crea
 * aquí: lo crea `geolocator_android` con el id `geolocator_channel_01` e
 * `IMPORTANCE_NONE` (silencioso, sin heads-up), que es exactamente lo que hace
 * falta. Su id es privado del plugin y no se puede sustituir; lo único que la
 * app decide es su nombre visible, desde `location_reporter.dart`. Crear aquí un
 * canal propio que nada usaría solo añadiría una entrada muerta a los Ajustes.
 */
class ZumbeoApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        crearCanales()
    }

    private fun crearCanales() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        CANALES_ANTIGUOS.forEach { manager.deleteNotificationChannel(it) }

        val ofertas = NotificationChannel(
            CANAL_OFERTAS,
            "Pedidos entrantes",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "El aviso de un pedido disponible. Suena con el volumen de llamada."
            enableVibration(true)
            setShowBadge(true)
            // La pieza que resuelve el problema real: USAGE_NOTIFICATION_RINGTONE
            // hace que el sonido salga por el flujo de audio de TIMBRE y no por el
            // de notificación, que en la mayoría de los teléfonos está muy por
            // debajo. Un conductor en moto y con casco no oye el de notificación.
            setSound(
                sonidoDeOferta(),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
        }
        manager.createNotificationChannel(ofertas)

        val avisos = NotificationChannel(
            CANAL_AVISOS,
            "Avisos generales",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Propuestas aceptadas, cancelaciones y avisos de la cuenta."
            enableVibration(true)
            setSound(Settings.System.DEFAULT_NOTIFICATION_URI, null)
        }
        manager.createNotificationChannel(avisos)
    }

    /**
     * ÚNICO punto donde se decide el sonido de una oferta.
     *
     * Hoy es el tono de llamada del sistema: dura más y es más audible que el de
     * notificación, y se reproduce una sola vez porque lo pide una notificación,
     * no una llamada. Para poner un tono propio basta devolver aquí
     * `Uri.parse("android.resource://$packageName/raw/<archivo>")`.
     *
     * Al hacerlo hay que SUBIR el id del canal a `_v2`: el sonido de un canal ya
     * creado no se puede cambiar y los teléfonos que ya lo tienen se quedarían
     * con el anterior sin que nada lo delate.
     */
    private fun sonidoDeOferta(): Uri =
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: Settings.System.DEFAULT_NOTIFICATION_URI

    companion object {
        /** Canal de las ofertas. Debe coincidir con el channelId del backend. */
        const val CANAL_OFERTAS = "motoya_oferta_v1"

        /**
         * Canal del resto de avisos. Debe coincidir con el
         * `default_notification_channel_id` del manifest y con el del backend.
         */
        const val CANAL_AVISOS = "motoya_avisos_v1"

        private val CANALES_ANTIGUOS = listOf(
            "motoya_alta_importancia_v2",
            "motoya_alta_importancia",
        )
    }
}
