package com.mmi.haraplay.media

import android.content.ContentResolver
import android.database.Cursor
import android.database.sqlite.SQLiteException
import android.os.Build
import android.provider.MediaStore
import android.provider.MediaStore.Audio.AudioColumns

/** Read-only MediaStore queries. Every method blocks; call off the main thread. */
class MediaStoreQueries(private val resolver: ContentResolver) {

    /**
     * Every music file as a map of plain values (see `MediaStoreSong.fromMap`
     * on the Dart side for the keys).
     */
    fun querySongs(): List<Map<String, Any?>> {
        val base = mutableListOf(
            AudioColumns._ID,
            AudioColumns.TITLE,
            AudioColumns.ARTIST,
            AudioColumns.ALBUM,
            AudioColumns.ALBUM_ID,
            AudioColumns.ARTIST_ID,
            AudioColumns.TRACK,
            AudioColumns.YEAR,
            AudioColumns.DURATION,
            AudioColumns.SIZE,
            AudioColumns.MIME_TYPE,
            @Suppress("DEPRECATION") AudioColumns.DATA,
            AudioColumns.DATE_ADDED,
            AudioColumns.DATE_MODIFIED,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            base += AudioColumns.GENRE
        }

        // ALBUM_ARTIST is public from API 30 but exists as a column on most
        // older devices too; fall back to a query without it if it does not.
        val cursor = try {
            query(base + ALBUM_ARTIST)
        } catch (e: IllegalArgumentException) {
            query(base)
        } catch (e: SQLiteException) {
            query(base)
        } ?: return emptyList()

        return cursor.use { c ->
            val songs = ArrayList<Map<String, Any?>>(c.count)
            while (c.moveToNext()) {
                songs += mapOf(
                    "id" to c.long(AudioColumns._ID),
                    "title" to c.string(AudioColumns.TITLE),
                    "artist" to c.string(AudioColumns.ARTIST),
                    "album" to c.string(AudioColumns.ALBUM),
                    "albumArtist" to c.string(ALBUM_ARTIST),
                    "albumId" to c.long(AudioColumns.ALBUM_ID),
                    "artistId" to c.long(AudioColumns.ARTIST_ID),
                    "genre" to c.string(GENRE),
                    "track" to c.long(AudioColumns.TRACK),
                    "year" to c.long(AudioColumns.YEAR),
                    "durationMs" to c.long(AudioColumns.DURATION),
                    "sizeBytes" to c.long(AudioColumns.SIZE),
                    "mimeType" to c.string(AudioColumns.MIME_TYPE),
                    "path" to c.string(@Suppress("DEPRECATION") AudioColumns.DATA),
                    "dateAddedSec" to c.long(AudioColumns.DATE_ADDED),
                    "dateModifiedSec" to c.long(AudioColumns.DATE_MODIFIED),
                )
            }
            songs
        }
    }

    /**
     * Genre name → song IDs. Only needed below API 30, where the audio table
     * has no GENRE column; returns an empty map on API 30+.
     */
    fun queryGenreMembership(): Map<String, List<Long>> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) return emptyMap()

        val genres = resolver.query(
            MediaStore.Audio.Genres.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.Audio.Genres._ID, MediaStore.Audio.Genres.NAME),
            null,
            null,
            null,
        ) ?: return emptyMap()

        val result = LinkedHashMap<String, MutableList<Long>>()
        genres.use { g ->
            while (g.moveToNext()) {
                val genreId = g.long(MediaStore.Audio.Genres._ID) ?: continue
                val name = g.string(MediaStore.Audio.Genres.NAME)?.trim()
                if (name.isNullOrEmpty()) continue

                val members = resolver.query(
                    MediaStore.Audio.Genres.Members.getContentUri("external", genreId),
                    arrayOf(MediaStore.Audio.Genres.Members.AUDIO_ID),
                    null,
                    null,
                    null,
                ) ?: continue
                members.use { m ->
                    val ids = result.getOrPut(name) { mutableListOf() }
                    while (m.moveToNext()) {
                        m.long(MediaStore.Audio.Genres.Members.AUDIO_ID)?.let(ids::add)
                    }
                }
            }
        }
        return result.filterValues { it.isNotEmpty() }
    }

    private fun query(projection: List<String>): Cursor? = resolver.query(
        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
        projection.toTypedArray(),
        "${AudioColumns.IS_MUSIC} != 0",
        null,
        "${AudioColumns.TITLE} COLLATE NOCASE ASC",
    )

    private companion object {
        // Literal names so they also work below the API level that made
        // them public.
        const val ALBUM_ARTIST = "album_artist"
        const val GENRE = "genre"
    }
}

/** Null when the column is missing from the projection or the value is null. */
private fun Cursor.string(column: String): String? {
    val index = getColumnIndex(column)
    return if (index < 0 || isNull(index)) null else getString(index)
}

private fun Cursor.long(column: String): Long? {
    val index = getColumnIndex(column)
    return if (index < 0 || isNull(index)) null else getLong(index)
}
