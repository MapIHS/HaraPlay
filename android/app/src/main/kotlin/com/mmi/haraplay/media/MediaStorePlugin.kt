package com.mmi.haraplay.media

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * `haraplay/media` method channel. Library queries run on one background
 * thread (in order); artwork loads run on a small pool so a long scan does
 * not hold up thumbnails.
 */
class MediaStorePlugin(context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val queries = MediaStoreQueries(context.contentResolver)
    private val artwork = ArtworkLoader(context.contentResolver)
    private val queryExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val artworkExecutor: ExecutorService = Executors.newFixedThreadPool(ARTWORK_THREADS)
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
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
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
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
    }
}
