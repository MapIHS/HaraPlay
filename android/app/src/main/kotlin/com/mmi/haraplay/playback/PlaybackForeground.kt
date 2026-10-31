package com.mmi.haraplay.playback

import android.app.Service
import android.content.Context
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import com.ryanheise.audioservice.AudioService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `haraplay/playback` channel. HaraPlay keeps the playback service in the
 * foreground while paused (so ColorOS keeps the lock-screen controls) and
 * stops it after a while. audio_service then only calls `stopSelf()`, which
 * does nothing while the app's UI is bound to the service, so the paused
 * notification would stay. [releaseForeground] takes the service out of the
 * foreground and removes the notification.
 *
 * audio_service exposes no API for this; its service instance is read by
 * reflection, and if that ever fails this does nothing (the notification
 * then simply stays, as before).
 */
class PlaybackForeground(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "haraplay/playback").also {
        it.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "releaseForeground" -> result.success(releaseForeground())
            "audioEffects" -> result.success(AudioEffectsProbe.probe(context))
            else -> result.notImplemented()
        }
    }

    fun dispose() = channel.setMethodCallHandler(null)

    private fun releaseForeground(): Boolean = try {
        val field = AudioService::class.java.getDeclaredField("instance")
        field.isAccessible = true
        val service = field.get(null) as? Service
        if (service != null) {
            ServiceCompat.stopForeground(service, ServiceCompat.STOP_FOREGROUND_REMOVE)
            // A metadata update may already have re-posted it as a plain
            // notification; remove that too.
            val id = AudioService::class.java.getDeclaredField("NOTIFICATION_ID").run {
                isAccessible = true
                getInt(null)
            }
            NotificationManagerCompat.from(service).cancel(id)
        }
        service != null
    } catch (e: ReflectiveOperationException) {
        Log.w("HaraPlay", "Could not release the playback foreground state", e)
        false
    }
}
