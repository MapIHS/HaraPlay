package com.mmi.haraplay.media

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * `haraplay/media` method channel. Library queries run on one background
 * thread (in order); artwork loads run on a small pool so a long scan does
 * not hold up thumbnails.
 *
 * It also watches MediaStore's audio table and tells Dart
 * (`mediaChanged`) once changes have settled, so the library can rescan
 * itself when files are added, removed or edited while the app runs.
 */
class MediaStorePlugin(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val queries = MediaStoreQueries(context.contentResolver)
    private val artwork = ArtworkLoader(context.contentResolver)
    private val queryExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val artworkExecutor: ExecutorService = Executors.newFixedThreadPool(ARTWORK_THREADS)
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Copying an album fires one notification per file: wait for quiet. */
    private val notifyChanged = Runnable { channel.invokeMethod("mediaChanged", null) }

    private val observer = object : ContentObserver(mainHandler) {
        override fun onChange(selfChange: Boolean, uri: Uri?) {
            mainHandler.removeCallbacks(notifyChanged)
            mainHandler.postDelayed(notifyChanged, CHANGE_SETTLE_MS)
        }
    }

    init {
        channel.setMethodCallHandler(this)
        try {
            context.contentResolver.registerContentObserver(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                true,
                observer,
            )
        } catch (e: SecurityException) {
            // Without media access there is nothing to watch.
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "querySongs" -> run(queryExecutor, result) { queries.querySongs() }
            "queryGenreMembership" -> run(queryExecutor, result) {
                queries.queryGenreMembership()
            }
            "loadArtwork" -> {
                val songId = call.argument<Number>("songId")?.toLong()
                val sizePx = call.argument<Number>("sizePx")?.toInt()
                if (songId == null || sizePx == null || sizePx <= 0) {
                    result.error("bad_args", "songId and a positive sizePx are required", null)
                    return
                }
                val albumId = call.argument<Number>("albumId")?.toLong()
                run(artworkExecutor, result) { artwork.load(songId, albumId, sizePx) }
            }
            "scaleArtwork" -> {
                val image = call.argument<ByteArray>("image")
                val sizePx = call.argument<Number>("sizePx")?.toInt()
                if (image == null || sizePx == null || sizePx <= 0) {
                    result.error("bad_args", "image and a positive sizePx are required", null)
                    return
                }
                run(artworkExecutor, result) { artwork.scale(image, sizePx) }
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        context.contentResolver.unregisterContentObserver(observer)
        mainHandler.removeCallbacks(notifyChanged)
        queryExecutor.shutdownNow()
        artworkExecutor.shutdownNow()
    }

    private fun run(executor: ExecutorService, result: MethodChannel.Result, work: () -> Any?) {
        executor.execute {
            try {
                val value = work()
                mainHandler.post { result.success(value) }
            } catch (e: SecurityException) {
                mainHandler.post { result.error("permission_denied", e.message, null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("media_store_error", e.message, e.javaClass.name) }
            }
        }
    }

    private companion object {
        const val CHANNEL = "haraplay/media"
        const val ARTWORK_THREADS = 3
        const val CHANGE_SETTLE_MS = 2000L
    }
}
