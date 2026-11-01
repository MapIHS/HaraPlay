package com.mmi.haraplay

import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * `haraplay/open` method channel: audio files opened with HaraPlay from
 * another app (ACTION_VIEW). Each one is described to Dart, which plays the
 * matching library song or the file itself.
 *
 * A file that arrives before Dart asked (`initialFile`, at startup) waits;
 * later ones are pushed (`opened`).
 */
class OpenWithPlugin(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var waiting: Map<String, Any?>? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialFile" -> {
                dartReady = true
                result.success(waiting)
                waiting = null
            }
            else -> result.notImplemented()
        }
    }

    /** From the activity's launch intent and [Activity.onNewIntent]. */
    fun handle(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        // Handled once: a recreated activity must not replay it.
        intent.action = null
        io.execute {
            val info = describe(uri)
            main.post {
                if (dartReady) channel.invokeMethod("opened", info) else waiting = info
            }
        }
    }

    private fun describe(uri: Uri): Map<String, Any?> {
        val meta = MediaMetadataRetriever()
        var title: String? = null
        var artist: String? = null
        var album: String? = null
        var durationMs: Long? = null
        try {
            meta.setDataSource(context, uri)
            title = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
            artist = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
            album = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
            durationMs = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
        } catch (e: Exception) {
            // Unreadable tags: the file name stands in.
        } finally {
            try { meta.release() } catch (e: Exception) { }
        }
        return mapOf(
            "uri" to uri.toString(),
            "mediaId" to mediaStoreId(uri),
            "path" to path(uri),
            "displayName" to queryString(uri, OpenableColumns.DISPLAY_NAME),
            "size" to querySize(uri),
            "title" to title,
            "artist" to artist,
            "album" to album,
            "durationMs" to durationMs,
        )
    }

    /** The MediaStore ID for `content://media/...` URIs. */
    private fun mediaStoreId(uri: Uri): Long? {
        if (uri.authority != MediaStore.AUTHORITY) return null
        return try { ContentUris.parseId(uri).takeIf { it >= 0 } } catch (e: Exception) { null }
    }

    /** The file path, if the URI is a file or its provider reveals it. */
    private fun path(uri: Uri): String? {
        if (uri.scheme == "file") return uri.path
        @Suppress("DEPRECATION")
        return queryString(uri, MediaStore.MediaColumns.DATA)
    }

    /** The file's size in bytes, which the opening app's provider reports. */
    private fun querySize(uri: Uri): Long? {
        if (uri.scheme == "file") return uri.path?.let { java.io.File(it).length() }
        return try {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
                ?.use { if (it.moveToFirst() && !it.isNull(0)) it.getLong(0) else null }
        } catch (e: Exception) {
            null
        }
    }

    private fun queryString(uri: Uri, column: String): String? = try {
        context.contentResolver.query(uri, arrayOf(column), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        }
    } catch (e: Exception) {
        null
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        io.shutdown()
    }

    companion object {
        const val CHANNEL = "haraplay/open"

        /**
         * Dart asked for the startup file. Process-wide: the Dart side (in
         * audio_service's cached engine) outlives a recreated activity and
         * won't ask again.
         */
        @Volatile
        private var dartReady = false
    }
}
