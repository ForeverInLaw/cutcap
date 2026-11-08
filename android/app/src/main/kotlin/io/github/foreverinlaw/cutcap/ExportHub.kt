package io.github.foreverinlaw.cutcap

import android.content.Context
import android.content.Intent

/**
 * The one export the process runs. [ExportChannel] hands a request over
 * with [start]; [ExportService] takes it once it runs in the foreground,
 * runs it and [report]s how it goes. The export belongs to the process,
 * not to the activity: it carries on when the app's Flutter engine goes
 * away, and only its notification then tells how it ended.
 *
 * Main thread only.
 */
object ExportHub {
    /** Where events go while the Dart side listens. */
    var listener: ((ExportEvent) -> Unit)? = null

    private var pending: ExportRequest? = null
    private var service: ExportService? = null

    val isBusy: Boolean get() = pending != null || service != null

    /**
     * Starts [ExportService] for [request]. Throws [IllegalStateException]
     * when Android refuses to start it (e.g. the app is in the background).
     */
    fun start(context: Context, request: ExportRequest) {
        check(!isBusy) { "An export is already running." }
        pending = request
        try {
            context.startForegroundService(Intent(context, ExportService::class.java))
        } catch (error: IllegalStateException) {
            pending = null
            throw error
        }
    }

    /** The request [service] is to run; null when it was cancelled before. */
    fun take(service: ExportService): ExportRequest? = pending?.also {
        pending = null
        this.service = service
    }

    fun report(event: ExportEvent) {
        if (event is ExportEvent.Outcome) service = null
        listener?.invoke(event)
    }

    /** Stops the export, which then reports [ExportEvent.Cancelled]. */
    fun cancel() {
        service?.cancel() ?: pending?.let {
            pending = null
            report(ExportEvent.Cancelled)
        }
    }
}
