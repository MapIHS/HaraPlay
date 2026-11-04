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

/**
 * Cover art as JPEG bytes. Artwork is always shown as a square filled
 * edge to edge, so images are cropped to the centre square and scaled
 * down (never up) to `sizePx`.
 */
class ArtworkLoader(private val resolver: ContentResolver) {

    /**
     * MediaStore's artwork for a song, or null when it has none. Blocks;
     * call off the main thread. On Android 7-9 this is the album's art,
     * which the system often keeps only as a small thumbnail.
     */
    fun load(songId: Long, albumId: Long?, sizePx: Int): ByteArray? {
        val bitmap = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val uri = ContentUris.withAppendedId(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    songId,
                )
                resolver.loadThumbnail(uri, Size(sizePx, sizePx), null)
            } else {
                albumId?.let { id ->
                    val uri = ContentUris.withAppendedId(LEGACY_ALBUM_ART_URI, id)
                    decodeSquare(sizePx) { resolver.openInputStream(uri)?.use(it) }
                }
            }
        } catch (e: FileNotFoundException) {
            null
        } catch (e: IOException) {
            null
        } ?: return null
        return encode(bitmap)
    }

    /**
     * An image read by the app itself (a picture embedded in the file, or
     * cover.jpg next to it), as a square JPEG of at most `sizePx`. Null if
     * the bytes aren't an image Android can decode.
     */
    fun scale(image: ByteArray, sizePx: Int): ByteArray? {
        val bitmap = decodeSquare(sizePx) { decode ->
            decode(image.inputStream())
        } ?: return null
        return encode(bitmap)
    }

    /**
     * Decodes the stream that [open] hands to its callback, subsampled to
     * no less than [sizePx] on the short side, then cropped to the centre
     * square and scaled down to [sizePx].
     */
    private fun decodeSquare(
        sizePx: Int,
        open: ((java.io.InputStream) -> Bitmap?) -> Bitmap?,
    ): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open { BitmapFactory.decodeStream(it, null, bounds); null }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sample = 1
        while (minOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= sizePx) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        val decoded = open { BitmapFactory.decodeStream(it, null, options) } ?: return null

        val side = minOf(decoded.width, decoded.height)
        val target = minOf(side, sizePx)
        val square = if (decoded.width == decoded.height) {
            decoded
        } else {
            Bitmap.createBitmap(
                decoded,
                (decoded.width - side) / 2,
                (decoded.height - side) / 2,
                side,
                side,
            )
        }
        if (square !== decoded) decoded.recycle()
        if (target == side) return square
        val scaled = Bitmap.createScaledBitmap(square, target, target, true)
        if (scaled !== square) square.recycle()
        return scaled
    }

    private fun encode(bitmap: Bitmap): ByteArray = try {
        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
            out.toByteArray()
        }
    } finally {
        bitmap.recycle()
    }

    private companion object {
        const val JPEG_QUALITY = 92
        val LEGACY_ALBUM_ART_URI: Uri = Uri.parse("content://media/external/audio/albumart")
    }
}
