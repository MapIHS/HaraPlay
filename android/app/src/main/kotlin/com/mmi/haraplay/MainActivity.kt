package com.mmi.haraplay

import com.mmi.haraplay.media.MediaStorePlugin
import com.mmi.haraplay.playback.PlaybackForeground
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

/** Shares audio_service's FlutterEngine, so playback survives the UI. */
class MainActivity : AudioServiceActivity() {
    private var mediaStore: MediaStorePlugin? = null
    private var playback: PlaybackForeground? = null
    private var systemColors: SystemColorsPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaStore?.dispose()
        mediaStore = MediaStorePlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        playback?.dispose()
        playback = PlaybackForeground(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        systemColors?.dispose()
        systemColors = SystemColorsPlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        mediaStore?.dispose()
        mediaStore = null
        playback?.dispose()
        playback = null
        systemColors?.dispose()
        systemColors = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
