package io.github.foreverinlaw.cutcap

import android.content.Context
import android.database.Cursor
import android.media.MediaExtractor
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import java.io.File

/**
 * A video as the Dart side names it: a `content://` URI string (what the
 * picker and shares hand over) or a plain file path.
 */
class VideoSource(private val context: Context, private val path: String) {
    private val uri: Uri? = Uri.parse(path).takeIf { it.scheme == "content" }

    fun open(extractor: MediaExtractor) {
        if (uri != null) extractor.setDataSource(context, uri, null) else extractor.setDataSource(path)
    }

    fun open(retriever: MediaMetadataRetriever) {
        if (uri != null) retriever.setDataSource(context, uri) else retriever.setDataSource(path)
    }

    /** Whether the video can still be read: present and access still granted. */
    fun canRead(): Boolean {
        if (uri == null) return File(path).canRead()
        return orNullIfRefused("open $uri") {
            context.contentResolver.openFileDescriptor(uri, "r")?.use { true }
        } ?: false
    }

    /** The name the system shows for the video, if it is known. */
    fun displayName(): String? {
        if (uri == null) return File(path).name
        return query { cursor ->
            cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME).takeIf { it >= 0 }
                ?.let(cursor::getString)
        }
    }

    /**
     * Size and modification time, which tell the video's versions apart
     * for the thumbnail cache; null when the provider reports either not,
     * or the video cannot be read.
     */
    fun stamp(): String? {
        if (uri == null) {
            val file = File(path)
            return if (file.canRead()) "${file.length()}|${file.lastModified()}" else null
        }
        return query { cursor ->
            fun long(column: String) =
                cursor.getColumnIndex(column).takeIf { it >= 0 && !cursor.isNull(it) }
                    ?.let(cursor::getLong)
            val size = long(OpenableColumns.SIZE)
            // Documents providers report milliseconds, MediaStore seconds.
            val modified = long("last_modified") ?: long(MediaStore.MediaColumns.DATE_MODIFIED)
            if (size != null && modified != null) "$size|$modified" else null
        }
    }

    private fun <T> query(read: (Cursor) -> T?): T? = orNullIfRefused("query $uri") {
        context.contentResolver.query(uri!!, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) read(cursor) else null
        }
    }
}

