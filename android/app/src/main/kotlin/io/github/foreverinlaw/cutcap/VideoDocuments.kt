package io.github.foreverinlaw.cutcap

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * `io.github.foreverinlaw.cutcap/documents` (Dart: `AndroidDocuments`):
 * the system picker, "Share → cutcap", and keeping read access to the
 * videos so a restored session can still open them (ADR 0003).
 *
 * Picked videos come from `ACTION_OPEN_DOCUMENT`, whose grants are taken as
 * persistable. A shared video's grant is usually temporary; it is kept by
 * persisting it when the sender allowed that, else by swapping in the same
 * video's MediaStore URI, which the video read permission keeps readable.
 *
 * Shares are queued until Dart asks for them (`takeShared` at launch,
 * `listenShared` once the editor is up); from `listenShared` on each share
 * is pushed as a `shared` call.
 */
class VideoDocuments(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingPick: MethodChannel.Result? = null
    private val queued = mutableListOf<String>()
    private var pushing = false

    /** Shares that wait for the answer to the video permission prompt. */
    private val awaitingPermission = mutableListOf<List<Uri>>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "exists" -> background(result) { VideoSource(activity, call.path()).canRead() }
            "stamp" -> background(result) { VideoSource(activity, call.path()).stamp() }
            "takeShared" -> result.success(drain())
            "listenShared" -> {
                pushing = true
                result.success(drain())
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() = io.shutdownNow()

    // Picking ----------------------------------------------------------------

    private fun pick(result: MethodChannel.Result) {
        if (pendingPick != null) return result.error("busy", "a picker is already open", null)
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("video/*")
            .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        pendingPick = result
        activity.startActivityForResult(intent, PICK_REQUEST)
    }

    /** Hands the picker's answer to Dart; false for other requests. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uris = if (resultCode == Activity.RESULT_OK && data != null) picked(data) else emptyList()
        uris.forEach(::persist)
        result.success(uris.map(Uri::toString))
        return true
    }

    /** Every picked URI in the order the picker lists them. */
    private fun picked(data: Intent): List<Uri> {
        val clips = data.clipData ?: return listOfNotNull(data.data)
        return (0 until clips.itemCount).mapNotNull { clips.getItemAt(it).uri }
    }

    // Sharing ----------------------------------------------------------------

    /** Takes the videos of an `ACTION_SEND`/`ACTION_SEND_MULTIPLE` intent. */
    fun onIntent(intent: Intent) {
        val uris = shared(intent)
        if (uris.isEmpty()) return
        val temporary = uris.filterNot(::persist)
        if (temporary.isEmpty() || hasVideoPermission()) return keep(uris)
        // The answer arrives in onRequestPermissionsResult; an earlier "don't
        // ask again" answers at once.
        awaitingPermission += uris
        if (awaitingPermission.size == 1) {
            activity.requestPermissions(arrayOf(videoPermission), PERMISSION_REQUEST)
        }
    }

    /** Delivers the shares that waited for the permission, granted or not. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val waiting = awaitingPermission.toList()
        awaitingPermission.clear()
        waiting.forEach(::keep)
        return true
    }

    private fun shared(intent: Intent): List<Uri> = when (intent.action) {
        Intent.ACTION_SEND -> listOfNotNull(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            },
        )
        Intent.ACTION_SEND_MULTIPLE ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
            }.orEmpty()
        else -> emptyList()
    }

    /** Swaps temporary URIs for durable ones off the main thread, then delivers. */
    private fun keep(uris: List<Uri>) = io.execute {
        val kept = uris.map { durable(it) ?: it }.map(Uri::toString)
        main.post { deliver(kept) }
    }

    private fun deliver(uris: List<String>) {
        if (pushing) channel.invokeMethod("shared", uris) else queued += uris
    }

    private fun drain(): List<String> = queued.toList().also { queued.clear() }

    // Keeping access ----------------------------------------------------------

    /** Keeps the grant across restarts; false when the sender did not allow it. */
    private fun persist(uri: Uri): Boolean = try {
        activity.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        true
    } catch (_: SecurityException) {
        false
    }

    /**
     * The same video's MediaStore URI, readable for as long as the video
     * permission stands; null when there is none (or no permission).
     */
    private fun durable(uri: Uri): Uri? {
        if (activity.contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission }) return uri
        if (!hasVideoPermission()) return null
        if (uri.authority == MediaStore.AUTHORITY) return uri
        val media = try {
            if (DocumentsContract.isDocumentUri(activity, uri)) MediaStore.getMediaUri(activity, uri) else null
        } catch (_: Exception) {
            // Not a document MediaStore knows.
            null
        } ?: sameVideoInMediaStore(uri)
        return media?.takeIf { VideoSource(activity, it.toString()).canRead() }
    }

    /** Looks the video up in MediaStore by its name and size. */
    private fun sameVideoInMediaStore(uri: Uri): Uri? {
        val resolver = activity.contentResolver
        val nameAndSize: Pair<String, Long>? = try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
                ?.use { if (it.moveToFirst() && !it.isNull(0)) it.getString(0) to it.getLong(1) else null }
        } catch (_: Exception) {
            // The sender's provider does not answer queries.
            null
        }
        val (name, size) = nameAndSize ?: return null
        val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        return resolver.query(
            collection,
            arrayOf(MediaStore.Video.Media._ID),
            "${MediaStore.Video.Media.DISPLAY_NAME} = ? AND ${MediaStore.Video.Media.SIZE} = ?",
            arrayOf(name, size.toString()),
            null,
        )?.use { if (it.moveToFirst()) ContentUris.withAppendedId(collection, it.getLong(0)) else null }
    }

    private fun hasVideoPermission() =
        activity.checkSelfPermission(videoPermission) == PackageManager.PERMISSION_GRANTED

    private val videoPermission =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_VIDEO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

    private fun background(result: MethodChannel.Result, work: () -> Any?) = io.execute {
        val value = work()
        main.post { result.success(value) }
    }

    private fun MethodCall.path(): String = argument<String>("path")!!

    private companion object {
        const val PICK_REQUEST = 0x6375
        const val PERMISSION_REQUEST = 0x6376
    }
}
