package com.mmi.haraplay

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * `haraplay/documents` method channel: save or open one small file through
 * Android's document picker (Storage Access Framework), so no storage
 * permission is needed. Used for `.m3u` playlist export and import.
 */
class DocumentFilesPlugin(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** The call waiting for the picker, and what to save if it is a save. */
    private var pending: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveFile" && call.method != "openFile") {
            result.notImplemented()
            return
        }
        if (pending != null) {
            result.error("busy", "A file picker is already open", null)
            return
        }
        val intent = when (call.method) {
            "saveFile" -> {
                pendingBytes = call.argument<ByteArray>("bytes")
                Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = call.argument<String>("mimeType") ?: "application/octet-stream"
                    putExtra(Intent.EXTRA_TITLE, call.argument<String>("fileName"))
                }
            }
            else -> Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                // File managers label playlists in many ways; filter loosely.
                type = "*/*"
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    call.argument<List<String>>("mimeTypes")?.toTypedArray(),
                )
            }
        }
        pending = result
        val requestCode = if (call.method == "saveFile") SAVE_REQUEST else OPEN_REQUEST
        try {
            activity.startActivityForResult(intent, requestCode)
        } catch (e: Exception) {
            finish { it.error("no_picker", e.message, null) }
        }
    }

    /** Forwarded from [MainActivity.onActivityResult]; true if handled. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SAVE_REQUEST && requestCode != OPEN_REQUEST) return false
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            finish { it.success(null) } // Cancelled.
            return true
        }
        if (requestCode == SAVE_REQUEST) save(uri) else open(uri)
        return true
    }

    private fun save(uri: Uri) {
        val bytes = pendingBytes ?: ByteArray(0)
        io.execute {
            try {
                activity.contentResolver.openOutputStream(uri, "wt")!!.use { it.write(bytes) }
                finish { it.success(displayName(uri) ?: true) }
            } catch (e: Exception) {
                finish { it.error("write_failed", e.message, null) }
            }
        }
    }

    private fun open(uri: Uri) {
        io.execute {
            try {
                val bytes = activity.contentResolver.openInputStream(uri)!!.use { input ->
                    val data = input.readBytes()
                    if (data.size > MAX_OPEN_BYTES) throw IllegalStateException("File too large")
                    data
                }
                val reply = mapOf(
                    "name" to displayName(uri),
                    "path" to guessPath(uri),
                    "bytes" to bytes,
                )
                finish { it.success(reply) }
            } catch (e: Exception) {
                finish { it.error("read_failed", e.message, null) }
            }
        }
    }

    private fun finish(reply: (MethodChannel.Result) -> Unit) {
        main.post {
            val result = pending ?: return@post
            pending = null
            pendingBytes = null
            reply(result)
        }
    }

    private fun displayName(uri: Uri): String? = try {
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }
    } catch (e: Exception) {
        null
    }

    /**
     * The file's path when the picker's provider reveals it (internal
     * storage, SD cards, some Downloads entries), so relative entries in a
     * playlist can be resolved. Null otherwise.
     */
    private fun guessPath(uri: Uri): String? {
        if (!DocumentsContract.isDocumentUri(activity, uri)) return null
        val id = DocumentsContract.getDocumentId(uri)
        return when (uri.authority) {
            "com.android.externalstorage.documents" -> {
                val split = id.split(":", limit = 2)
                if (split.size != 2) return null
                val base = if (split[0] == "primary") "/storage/emulated/0" else "/storage/${split[0]}"
                "$base/${split[1]}"
            }
            "com.android.providers.downloads.documents" ->
                if (id.startsWith("raw:")) id.removePrefix("raw:") else null
            else -> null
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        io.shutdown()
        pending?.success(null)
        pending = null
    }

    companion object {
        const val CHANNEL = "haraplay/documents"
        const val SAVE_REQUEST = 0x4D33 // "M3"
        const val OPEN_REQUEST = 0x4D34
        const val MAX_OPEN_BYTES = 5 * 1024 * 1024
    }
}
