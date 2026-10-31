package com.mmi.haraplay.playback

import android.content.Context
import android.media.AudioManager
import android.media.audiofx.AudioEffect
import android.media.audiofx.Equalizer
import android.util.Log

/**
 * Which audio effects this device offers, before the player creates them.
 * just_audio builds its Equalizer / LoudnessEnhancer while loading a song,
 * and on a device without them that creation throws; the app only attaches
 * the effects reported here.
 *
 * The band layout is read from a short-lived Equalizer on a fresh audio
 * session, so the equalizer screen can be drawn before anything plays.
 */
object AudioEffectsProbe {
    fun probe(context: Context): Map<String, Any?> {
        val types = try {
            AudioEffect.queryEffects().map { it.type }.toSet()
        } catch (e: RuntimeException) {
            Log.w("HaraPlay", "Could not list audio effects", e)
            emptySet()
        }
        val loudness = AudioEffect.EFFECT_TYPE_LOUDNESS_ENHANCER in types
        val equalizer =
            if (AudioEffect.EFFECT_TYPE_EQUALIZER in types) equalizerLayout(context) else null
        return mapOf("equalizer" to equalizer, "loudness" to loudness)
    }

    private fun equalizerLayout(context: Context): Map<String, Any>? {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        var equalizer: Equalizer? = null
        return try {
            equalizer = Equalizer(0, audio.generateAudioSessionId())
            val range = equalizer.bandLevelRange
            mapOf(
                "minDecibels" to range[0] / 100.0, // millibel → dB
                "maxDecibels" to range[1] / 100.0,
                // milliHertz → Hz
                "bands" to (0 until equalizer.numberOfBands).map {
                    equalizer.getCenterFreq(it.toShort()) / 1000.0
                },
            )
        } catch (e: Exception) {
            // UnsupportedOperationException, IllegalStateException, ...
            Log.w("HaraPlay", "Equalizer not available", e)
            null
        } finally {
            equalizer?.release()
        }
    }
}
