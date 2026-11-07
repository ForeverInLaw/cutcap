package io.github.foreverinlaw.cutcap

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/**
 * `io.github.foreverinlaw.cutcap/media`: probing and filmstrip thumbnails
 * (Dart: `AndroidMediaProbe`, `AndroidThumbnailSource`). Work runs off the
 * main thread; probes in parallel, thumbnail passes one at a time.
 */
class MediaChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    private val probes: ExecutorService = Executors.newFixedThreadPool(2)
    private val thumbnails: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
            ?: return result.error("bad_args", "path missing", null)
        val video = VideoSource(context, path)
        when (call.method) {
            "probe" -> run(probes, result, video) { probe(video) }
            "thumbnails" -> {
                val height = call.argument<Int>("height") ?: 96
                val shots = call.argument<List<Map<String, Any>>>("shots").orEmpty()
                run(thumbnails, result, video) { renderThumbnails(video, height, shots) }
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        probes.shutdownNow()
        thumbnails.shutdownNow()
    }

    private fun run(
        executor: ExecutorService,
        result: MethodChannel.Result,
        video: VideoSource,
        work: () -> Any?,
    ) = executor.execute {
        try {
            val value = work()
            main.post { result.success(value) }
        } catch (error: Exception) {
            // The video's name goes along so the editor can name what failed.
            val name = video.displayName()
            main.post { result.error("unreadable", error.toString(), name) }
        }
    }

    /** Raw facts; `AndroidMediaProbe.parse` documents the shape and decides. */
    private fun probe(video: VideoSource): Map<String, Any?> {
        val extractor = MediaExtractor()
        val retriever = MediaMetadataRetriever()
        try {
            video.open(extractor)
            video.open(retriever)
            var track: Map<String, Any?>? = null
            val audio = mutableListOf<Map<String, Any?>>()
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                when {
                    mime.startsWith("video/") && track == null ->
                        track = videoTrack(extractor, retriever, index, format, mime)
                    mime.startsWith("audio/") ->
                        audio += mapOf("mime" to mime, "bitRate" to format.int(MediaFormat.KEY_BIT_RATE))
                }
            }
            fun metadata(key: Int) = retriever.extractMetadata(key)?.toLongOrNull()
            return mapOf(
                "name" to video.displayName(),
                "video" to track,
                "audio" to audio,
                "frameCount" to metadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT),
                "durationUs" to metadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.times(1000),
                "bitRate" to metadata(MediaMetadataRetriever.METADATA_KEY_BITRATE),
            )
        } finally {
            extractor.release()
            retriever.release()
        }
    }

    private fun videoTrack(
        extractor: MediaExtractor,
        retriever: MediaMetadataRetriever,
        index: Int,
        format: MediaFormat,
        mime: String,
    ): Map<String, Any?> {
        val rotation = format.int(MediaFormat.KEY_ROTATION)
            ?: retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull()
        return mapOf(
            "mime" to mime,
            "decodable" to (MediaCodecList(MediaCodecList.REGULAR_CODECS).findDecoderForFormat(format) != null),
            "width" to format.int(MediaFormat.KEY_WIDTH),
            "height" to format.int(MediaFormat.KEY_HEIGHT),
            "rotation" to rotation,
            "durationUs" to format.long(MediaFormat.KEY_DURATION),
            "bitRate" to format.int(MediaFormat.KEY_BIT_RATE),
            "frameRate" to (if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) format.getNumber(MediaFormat.KEY_FRAME_RATE)?.toDouble() else null),
            "sampleTimesUs" to sampleTimes(extractor, index),
        )
    }

    /** Presentation times of the first frames, in the order they are stored. */
    private fun sampleTimes(extractor: MediaExtractor, index: Int): List<Long> {
        extractor.selectTrack(index)
        extractor.seekTo(0, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        val times = mutableListOf<Long>()
        while (times.size < SAMPLED_FRAMES) {
            val time = extractor.sampleTime
            if (time < 0) break
            times += time
            if (!extractor.advance()) break
        }
        extractor.unselectTrack(index)
        return times
    }

    /**
     * Writes each shot's nearest sync frame (ADR 0002), upright and [height]
     * px tall, as a JPEG; a file appears only once complete. Returns how
     * many were written and throws when none could be.
     */
    private fun renderThumbnails(video: VideoSource, height: Int, shots: List<Map<String, Any>>): Int {
        val retriever = MediaMetadataRetriever()
        try {
            video.open(retriever)
            var rendered = 0
            var failure: Exception? = null
            for (shot in shots) {
                val seekUs = (shot["seekUs"] as Number).toLong()
                val file = File(shot["file"] as String)
                try {
                    // Frames come back upright; the box only bounds the decode size.
                    val frame = retriever.getScaledFrameAtTime(
                        seekUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, height * 4, height,
                    ) ?: continue
                    val scaled = if (frame.height == height) frame else Bitmap.createScaledBitmap(
                        frame, (frame.width * height.toFloat() / frame.height).roundToInt().coerceAtLeast(1), height, true,
                    )
                    val partial = File(file.path + ".part")
                    partial.outputStream().use { scaled.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, it) }
                    if (partial.renameTo(file)) rendered++ else partial.delete()
                } catch (error: Exception) {
                    failure = error
                }
            }
            if (rendered == 0 && shots.isNotEmpty()) throw failure ?: IllegalStateException("no frames")
            return rendered
        } finally {
            retriever.release()
        }
    }

    private fun MediaFormat.int(key: String): Int? = if (containsKey(key)) getInteger(key) else null

    private fun MediaFormat.long(key: String): Long? = if (containsKey(key)) getLong(key) else null

    private companion object {
        /** Enough frames to read the rate past a few dropped or doubled ones. */
        const val SAMPLED_FRAMES = 600
        const val JPEG_QUALITY = 80
    }
}
