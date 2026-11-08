package io.github.foreverinlaw.cutcap

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/**
 * Runs the export [ExportHub] hands over as a foreground service, so it
 * goes on while the app is in the background: Media3 renders into the
 * app's cache, then the video is copied into Movies/cutcap. Its
 * notification shows progress and a Cancel action; the result is posted
 * as a notification of its own.
 *
 * Foreground type: `mediaProcessing` on Android 15+, which is meant for
 * transcoding; `dataSync` before it, the closest type Android 14 has.
 */
class ExportService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private lateinit var notifications: ExportNotifications
    private var export: Media3Export? = null
    private var saving = false
    private var shownPercent: Int? = null

    private val output: File get() = File(cacheDir, "exports/export.mp4")

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        notifications = ExportNotifications(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL) {
            if (export == null && !saving) stopSelf()
            cancel()
            return START_NOT_STICKY
        }
        // Android requires this soon after startForegroundService, even when
        // the export was cancelled in the meantime.
        startForeground(ExportNotifications.PROGRESS_ID, notifications.progress(null), foregroundType())
        if (export != null || saving) return START_NOT_STICKY
        val request = ExportHub.take(this)
        if (request == null) {
            finish()
            return START_NOT_STICKY
        }
        output.parentFile?.listFiles()?.forEach(File::delete)
        output.parentFile?.mkdirs()
        try {
            export = Media3Export(this, request, output) { outcome -> onRendered(request, outcome) }
                .also(Media3Export::start)
        } catch (error: RuntimeException) {
            // E.g. a source URI Media3 cannot open at all.
            end(ExportEvent.Failed.of(ExportEvent.Failed.Kind.CANNOT_START, error))
            return START_NOT_STICKY
        }
        main.post(::poll)
        return START_NOT_STICKY
    }

    /** Stops the export; ignored once rendering is done and the video is being saved. */
    fun cancel() {
        val running = export ?: return
        running.cancel()
        output.delete()
        end(ExportEvent.Cancelled)
    }

    /** Android 15+ ends foreground work after its daily time limit. */
    override fun onTimeout(startId: Int, fgsType: Int) {
        export?.cancel()
        output.delete()
        end(ExportEvent.Failed(ExportEvent.Failed.Kind.TIME_LIMIT))
    }

    override fun onDestroy() {
        // Only reached early when Android stops the service itself.
        if (export != null) {
            export?.cancel()
            output.delete()
            end(ExportEvent.Failed(ExportEvent.Failed.Kind.STOPPED))
        }
        main.removeCallbacksAndMessages(null)
        io.shutdown()
        super.onDestroy()
    }

    private fun poll() {
        val running = export ?: return
        running.progress()?.let { fraction ->
            ExportHub.report(ExportEvent.Progress(fraction))
            val percent = (fraction * 100).roundToInt()
            if (percent != shownPercent) {
                shownPercent = percent
                notifications.update(percent)
            }
        }
        main.postDelayed(::poll, POLL_MS)
    }

    private fun onRendered(request: ExportRequest, outcome: ExportEvent.Outcome) {
        export = null
        if (outcome !is ExportEvent.Succeeded) {
            output.delete()
            return end(outcome)
        }
        saving = true
        io.execute {
            val saved = try {
                val (uri, name) = MoviesFolder(this).add(output, request.name)
                ExportEvent.Succeeded(uri.toString(), name)
            } catch (error: Exception) {
                ExportEvent.Failed.of(ExportEvent.Failed.Kind.CANNOT_WRITE, error)
            } finally {
                output.delete()
            }
            main.post {
                saving = false
                end(saved)
            }
        }
    }

    private fun end(outcome: ExportEvent.Outcome) {
        export = null
        main.removeCallbacksAndMessages(null)
        when (outcome) {
            is ExportEvent.Succeeded -> notifications.saved(Uri.parse(outcome.uri), outcome.name)
            is ExportEvent.Failed -> notifications.failed(outcome)
            ExportEvent.Cancelled -> Unit
        }
        ExportHub.report(outcome)
        finish()
    }

    private fun finish() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun foregroundType() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
    } else {
        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
    }

    companion object {
        const val ACTION_CANCEL = "io.github.foreverinlaw.cutcap.action.CANCEL_EXPORT"
        private const val POLL_MS = 500L
    }
}
