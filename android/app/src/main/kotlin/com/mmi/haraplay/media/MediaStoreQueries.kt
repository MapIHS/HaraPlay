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
     * Every music file, column by column (decoded by `MediaStoreSong.fromColumns`
     * on the Dart side). Numbers travel as packed `LongArray`s with [NO_VALUE]
     * for null; text that repeats across songs (artist, album, genre, folder,
     * MIME type) is sent once in `strings` and referenced by index (-1 = null).
     * This is much smaller and faster to decode than one map per song.
     */
    fun querySongs(): Map<String, Any?> {
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
        } ?: return emptyMap()

        return cursor.use { c ->
            val n = c.count
            val longColumns = linkedMapOf(
                "id" to AudioColumns._ID,
                "albumId" to AudioColumns.ALBUM_ID,
                "artistId" to AudioColumns.ARTIST_ID,
                "track" to AudioColumns.TRACK,
                "year" to AudioColumns.YEAR,
                "durationMs" to AudioColumns.DURATION,
                "sizeBytes" to AudioColumns.SIZE,
                "dateAddedSec" to AudioColumns.DATE_ADDED,
                "dateModifiedSec" to AudioColumns.DATE_MODIFIED,
            )
            val sharedColumns = linkedMapOf(
                "artist" to AudioColumns.ARTIST,
                "album" to AudioColumns.ALBUM,
                "albumArtist" to ALBUM_ARTIST,
                "genre" to GENRE,
                "mimeType" to AudioColumns.MIME_TYPE,
            )
            val longs = longColumns.mapValues { LongArray(n) }
            val longIndex = longColumns.mapValues { c.getColumnIndex(it.value) }
            val shared = sharedColumns.mapValues { IntArray(n) }
            val sharedIndex = sharedColumns.mapValues { c.getColumnIndex(it.value) }
            val folders = IntArray(n)
            val titles = ArrayList<String?>(n)
            val fileNames = ArrayList<String?>(n)
            val strings = ArrayList<String>()
            val stringIds = HashMap<String, Int>()
            fun intern(value: String?): Int =
                if (value == null) -1 else stringIds.getOrPut(value) {
                    strings += value
                    strings.size - 1
                }
            // Android 9's scanner (and ID3 "ISO-8859-1" frames) can turn
            // Japanese, Chinese or Korean tags into Latin-1 mojibake.
            val repaired = HashMap<String, String>()
            fun tag(value: String?): String? =
                value?.let { repaired.getOrPut(it) { TextRepair.repair(it) } }
            @Suppress("DEPRECATION")
            val dataIndex = c.getColumnIndex(AudioColumns.DATA)
            val titleIndex = c.getColumnIndex(AudioColumns.TITLE)

            var row = 0
            while (c.moveToNext() && row < n) {
                for ((key, values) in longs) {
                    val i = longIndex.getValue(key)
                    values[row] = if (i < 0 || c.isNull(i)) NO_VALUE else c.getLong(i)
                }
                for ((key, values) in shared) {
                    val i = sharedIndex.getValue(key)
                    val value = if (i < 0 || c.isNull(i)) null else c.getString(i)
                    // The MIME type is never mojibake.
                    values[row] = intern(if (key == "mimeType") value else tag(value))
                }
                val path = if (dataIndex < 0 || c.isNull(dataIndex)) null else c.getString(dataIndex)
                val title = if (titleIndex < 0 || c.isNull(titleIndex)) null else c.getString(titleIndex)
                // The file name often has the title right: it breaks ties.
                titles += title?.let { TextRepair.repair(it, hint = path?.substringAfterLast('/')) }
                val slash = path?.lastIndexOf('/') ?: -1
                if (path == null || slash < 0) {
                    folders[row] = -1
                    fileNames += path
                } else {
                    folders[row] = intern(path.substring(0, slash))
                    fileNames += path.substring(slash + 1)
                }
                row++
            }

            mapOf(
                "count" to row,
                "noValue" to NO_VALUE,
                "strings" to strings,
                "longs" to longs,
                "shared" to shared,
                "folders" to folders,
                "titles" to titles,
                "fileNames" to fileNames,
            )
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
        // No ORDER BY: the app sorts in its own database, and sorting 5k rows
        // by a collated title costs MediaStore noticeable time.
        null,
    )

    private companion object {
        // Literal names so they also work below the API level that made
        // them public.
        const val ALBUM_ARTIST = "album_artist"
        const val GENRE = "genre"

        /** Stands for null in the packed number columns. */
        const val NO_VALUE = Long.MIN_VALUE
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
