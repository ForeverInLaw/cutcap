package io.github.foreverinlaw.cutcap

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Movies/cutcap in shared storage, through MediaStore: no permission is
 * needed to add videos there (API 29+), and the gallery shows them at once.
 */
class MoviesFolder(private val context: Context) {
    /**
     * Copies [video] in as [name] and returns its URI and the name MediaStore
     * gave it (it appends a number when the name is taken). The entry stays
     * pending, hidden from other apps, until the copy is complete; a failed
     * copy leaves nothing behind.
     */
    fun add(video: File, name: String): Pair<Uri, String?> {
        val resolver = context.contentResolver
        val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val pending = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, name)
            put(MediaStore.Video.Media.MIME_TYPE, MP4)
            put(MediaStore.Video.Media.RELATIVE_PATH, RELATIVE_PATH)
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, pending)
            ?: throw IllegalStateException("MediaStore refused a new video in $RELATIVE_PATH")
        try {
            val sink = resolver.openOutputStream(uri) ?: throw IllegalStateException("cannot write $uri")
            sink.use { video.inputStream().use { source -> source.copyTo(it) } }
            resolver.update(uri, ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }, null, null)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
        return uri to displayName(uri)
    }

    private fun displayName(uri: Uri): String? =
        context.contentResolver.query(uri, arrayOf(MediaStore.Video.Media.DISPLAY_NAME), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }

    companion object {
        const val MP4 = "video/mp4"
        val RELATIVE_PATH = "${Environment.DIRECTORY_MOVIES}/cutcap"
    }
}
