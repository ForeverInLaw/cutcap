package io.github.foreverinlaw.cutcap

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Dart side of exporting (`AndroidExportEngine`, `AndroidExports`):
 *
 * - `io.github.foreverinlaw.cutcap/export/run` (events): listening with an
 *   [ExportRequest] map starts the export through [ExportHub] and streams
 *   its [ExportEvent]s, ending after the outcome; cancelling the listen
 *   cancels the export.
 * - `io.github.foreverinlaw.cutcap/export` (methods): `cancel`, and `open`
 *   / `share` of a saved video's URI.
 */
class ExportChannel(private val activity: Activity) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private val listener: (ExportEvent) -> Unit = ::deliver

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val request = try {
            ExportRequest.from(arguments as? Map<*, *> ?: emptyMap<Any, Any>())
        } catch (error: IllegalArgumentException) {
            return refuse(events, "bad_request", "Bad export request: ${error.message}")
        }
        if (ExportHub.isBusy) return refuse(events, "busy", "An export is already running.")
        askToPostNotifications()
        sink = events
        ExportHub.listener = listener
        try {
            ExportHub.start(activity, request)
        } catch (error: IllegalStateException) {
            detach()
            refuse(events, "not_started", error.message ?: error.javaClass.simpleName)
        }
    }

    override fun onCancel(arguments: Any?) {
        // Also reached after the outcome, when nothing runs any more.
        if (sink == null) return
        detach()
        ExportHub.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "cancel" -> {
                ExportHub.cancel()
                result.success(null)
            }
            "open" -> launch(result) {
                Intent(Intent.ACTION_VIEW)
                    .setDataAndType(call.uri(), MoviesFolder.MP4)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            "share" -> launch(result) {
                val uri = call.uri()
                val send = Intent(Intent.ACTION_SEND)
                    .setType(MoviesFolder.MP4)
                    .putExtra(Intent.EXTRA_STREAM, uri)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                // The clip lets the share sheet show the video's preview.
                send.clipData = ClipData.newRawUri(null, uri)
                Intent.createChooser(send, null)
            }
            else -> result.notImplemented()
        }
    }

    /** The app's engine is going away; a running export carries on without it. */
    fun dispose() = detach()

    private fun deliver(event: ExportEvent) {
        val events = sink ?: return
        events.success(event.toMap())
        if (event is ExportEvent.Outcome) {
            detach()
            events.endOfStream()
        }
    }

    private fun detach() {
        sink = null
        if (ExportHub.listener === listener) ExportHub.listener = null
    }

    private fun refuse(events: EventChannel.EventSink, code: String, message: String) {
        events.error(code, message, null)
        events.endOfStream()
    }

    /** Without the permission (Android 13+) the export runs with its notification hidden. */
    private fun askToPostNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (activity.checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            activity.requestPermissions(arrayOf(permission), NOTIFICATIONS_REQUEST)
        }
    }

    private fun launch(result: MethodChannel.Result, intent: () -> Intent) {
        try {
            activity.startActivity(intent())
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("no_app", "No app opens this video: ${error.message}", null)
        }
    }

    private fun MethodCall.uri(): Uri = Uri.parse(argument<String>("uri")!!)

    private companion object {
        const val NOTIFICATIONS_REQUEST = 0x6377
    }
}
