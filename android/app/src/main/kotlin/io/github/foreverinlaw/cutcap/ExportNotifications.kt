package io.github.foreverinlaw.cutcap

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

/**
 * The export's notifications: progress with Cancel while it runs (the
 * foreground service's own), then how it ended. All silent, on one
 * low-importance channel. Without the notification permission (Android 13+)
 * Android hides them; the export runs the same.
 */
class ExportNotifications(private val context: Context) {
    private val manager = context.getSystemService(NotificationManager::class.java)

    init {
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, context.getString(R.string.export_channel), NotificationManager.IMPORTANCE_LOW),
        )
    }

    /** While exporting: [percent] done, or an open-ended bar until Media3 can tell. */
    fun progress(percent: Int?): Notification {
        val cancel = PendingIntent.getService(
            context,
            0,
            Intent(context, ExportService::class.java).setAction(ExportService.ACTION_CANCEL),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return builder()
            .setContentTitle(context.getString(R.string.export_running))
            .setContentText(percent?.let { "$it %" })
            .setProgress(100, percent ?: 0, percent == null)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setContentIntent(openApp())
            .addAction(Notification.Action.Builder(null, context.getString(R.string.export_cancel), cancel).build())
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
                }
            }
            .build()
    }

    /** Shows [percent] in the running export's notification. */
    fun update(percent: Int) = manager.notify(PROGRESS_ID, progress(percent))

    /** The video is saved; tapping the notification plays it. */
    fun saved(uri: Uri, name: String?) {
        val play = PendingIntent.getActivity(
            context,
            0,
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, MoviesFolder.MP4)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        post(
            builder()
                .setContentTitle(context.getString(R.string.export_saved))
                .setContentText(name)
                .setContentIntent(play)
                .setAutoCancel(true)
                .build(),
        )
    }

    /** Nothing was saved; [reason] goes in the expanded text. */
    fun failed(reason: String) {
        val intact = context.getString(R.string.export_edit_intact)
        post(
            builder()
                .setContentTitle(context.getString(R.string.export_failed))
                .setContentText(intact)
                .setStyle(Notification.BigTextStyle().bigText("$intact\n$reason"))
                .setContentIntent(openApp())
                .setAutoCancel(true)
                .build(),
        )
    }

    private fun builder() = Notification.Builder(context, CHANNEL).setSmallIcon(R.drawable.ic_stat_export)

    private fun post(notification: Notification) = manager.notify(RESULT_ID, notification)

    /** Brings the editor back (it is singleTask). */
    private fun openApp(): PendingIntent? = context.packageManager.getLaunchIntentForPackage(context.packageName)
        ?.let { PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_IMMUTABLE) }

    companion object {
        /** The foreground service's notification. */
        const val PROGRESS_ID = 1

        /** How the last export ended; replaced by the next one. */
        const val RESULT_ID = 2

        private const val CHANNEL = "export"
    }
}
