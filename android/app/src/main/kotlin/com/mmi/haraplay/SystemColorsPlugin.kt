package com.mmi.haraplay

import android.content.Context
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `haraplay/system` method channel: the wallpaper-based system colours
 * (Material You tonal palettes, Android 12+) for the "Wallpaper" colour
 * option. Returns null on older Android versions.
 */
class SystemColorsPlugin(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "systemTones" -> result.success(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) tones() else null,
            )
            else -> result.notImplemented()
        }
    }

    /** Only the tones the app's palette uses, keyed like the resources. */
    private fun tones(): Map<String, Long> {
        val ids = mapOf(
            "accent1_200" to android.R.color.system_accent1_200,
            "accent1_600" to android.R.color.system_accent1_600,
            "neutral1_10" to android.R.color.system_neutral1_10,
            "neutral1_50" to android.R.color.system_neutral1_50,
            "neutral1_800" to android.R.color.system_neutral1_800,
            "neutral1_900" to android.R.color.system_neutral1_900,
            "neutral2_50" to android.R.color.system_neutral2_50,
            "neutral2_100" to android.R.color.system_neutral2_100,
            "neutral2_200" to android.R.color.system_neutral2_200,
            "neutral2_400" to android.R.color.system_neutral2_400,
            "neutral2_600" to android.R.color.system_neutral2_600,
        )
        // As unsigned ARGB, so Dart gets a positive int.
        return ids.mapValues { (_, id) -> context.getColor(id).toLong() and 0xFFFFFFFFL }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL = "haraplay/system"
    }
}
