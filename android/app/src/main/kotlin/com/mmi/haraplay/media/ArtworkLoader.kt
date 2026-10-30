package com.mmi.haraplay.media

import android.content.ContentResolver
import android.content.ContentUris
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import java.io.ByteArrayOutputStream
import java.io.FileNotFoundException
import java.io.IOException

/** Loads cover art as JPEG bytes, scaled to fit a square of `sizePx`. */
class ArtworkLoader(private val resolver: ContentResolver) {

    /** Returns null when the song has no artwork. Blocks; call off the main thread. */
    fun load(songId: Long, albumId: Long?, sizePx: Int): ByteArray? {
        val bitmap = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val uri = ContentUris.withAppendedId(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    songId,
                )
                resolver.loadThumbnail(uri, Size(sizePx, sizePx), null)
            } else {
                albumId?.let { loadLegacyAlbumArt(it, sizePx) }
            }
        } catch (e: FileNotFoundException) {
            null
        } catch (e: IOException) {
            null
        } ?: return null

        return try {
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
                out.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }

    /** API 24-28: the album-art provider, decoded with subsampling. */
    private fun loadLegacyAlbumArt(albumId: Long, sizePx: Int): Bitmap? {
        val uri = ContentUris.withAppendedId(LEGACY_ALBUM_ART_URI, albumId)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sample = 1
        while (minOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= sizePx) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        val decoded = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        } ?: return null

        val scale = sizePx.toFloat() / maxOf(decoded.width, decoded.height)
        if (scale >= 1f) return decoded
        val scaled = Bitmap.createScaledBitmap(
            decoded,
            (decoded.width * scale).toInt().coerceAtLeast(1),
            (decoded.height * scale).toInt().coerceAtLeast(1),
            true,
        )
        if (scaled !== decoded) decoded.recycle()
        return scaled
    }

    private companion object {
        const val JPEG_QUALITY = 90
        val LEGACY_ALBUM_ART_URI: Uri = Uri.parse("content://media/external/audio/albumart")
    }
}
