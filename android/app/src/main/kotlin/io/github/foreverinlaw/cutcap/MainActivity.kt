package io.github.foreverinlaw.cutcap

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The editor. Hosts the platform channels the Dart side talks to and feeds
 * "Share → cutcap" intents to [VideoDocuments]: the one that started the
 * activity, then each one that reaches the running instance (singleTask).
 */
class MainActivity : FlutterActivity() {
    private var media: MediaChannel? = null
    private var documents: VideoDocuments? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        media = MediaChannel(applicationContext).also {
            MethodChannel(messenger, "io.github.foreverinlaw.cutcap/media").setMethodCallHandler(it)
        }
        val documentsChannel = MethodChannel(messenger, "io.github.foreverinlaw.cutcap/documents")
        documents = VideoDocuments(this, documentsChannel).also(documentsChannel::setMethodCallHandler)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A recreated activity, or one reopened from Recents, carries the
        // share it was first started with; that one was taken already.
        val relaunched = savedInstanceState != null ||
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if (!relaunched) documents?.onIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        documents?.onIntent(intent)
    }

    // FlutterActivity has no ActivityResultRegistry; this is its result path.
    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (documents?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (documents?.onRequestPermissionsResult(requestCode) != true) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        media?.dispose()
        documents?.dispose()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
