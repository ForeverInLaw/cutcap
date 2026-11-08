package io.github.foreverinlaw.cutcap

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.ChannelMixingAudioProcessor
import androidx.media3.common.audio.ChannelMixingMatrix
import androidx.media3.common.audio.SonicAudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File

/**
 * Renders an [ExportRequest] to an H.264/AAC mp4 at [output] with Media3
 * Transformer, by the same output rules as the Windows ffmpeg export:
 *
 * - one sequence of the clips, each clipped to its span;
 * - every clip fitted into the first clip's upright size with black bars
 *   (Transformer applies each source's rotation before the effects);
 * - frames above the output rate dropped (Media3 does not repeat frames, so
 *   a slower clip keeps its own rate);
 * - silence for clips without audio (the sequence always carries audio),
 *   resampled to the planned rate in stereo;
 * - HDR sources tone-mapped to SDR (the Windows export does not tone-map,
 *   ADR 0002 and 0004);
 * - the platform's (hardware) encoders, at the planned bitrates.
 *
 * Create, [start], poll [progress] and [cancel] on the main thread.
 */
// Encoder settings, frame dropping and the composition builders are
// Media3 "unstable" API: they may change between Media3 versions.
@OptIn(UnstableApi::class)
class Media3Export(
    context: Context,
    private val request: ExportRequest,
    private val output: File,
    private val onEnd: (ExportEvent.Outcome) -> Unit,
) {
    private val progressHolder = ProgressHolder()

    private val transformer = Transformer.Builder(context)
        .setVideoMimeType(MimeTypes.VIDEO_H264)
        .setAudioMimeType(MimeTypes.AUDIO_AAC)
        .setEncoderFactory(
            DefaultEncoderFactory.Builder(context)
                .setRequestedVideoEncoderSettings(
                    VideoEncoderSettings.Builder().setBitrate(request.videoBitRate).build(),
                )
                .setRequestedAudioEncoderSettings(
                    AudioEncoderSettings.Builder().setBitrate(request.audioBitRate).build(),
                )
                .build(),
        )
        .addListener(object : Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) =
                onEnd(ExportEvent.Succeeded(output.path, null))

            override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) =
                onEnd(
                    ExportEvent.Failed.of(
                        ExportEvent.Failed.Kind.FAILED,
                        exportException,
                        code = exportException.errorCodeName,
                    ),
                )
        })
        .build()

    fun start() = transformer.start(composition(), output.path)

    /** Share of the output written so far, while Media3 can tell. */
    fun progress(): Double? =
        if (transformer.getProgress(progressHolder) == Transformer.PROGRESS_STATE_AVAILABLE) {
            progressHolder.progress / 100.0
        } else {
            null
        }

    /** Stops the export; Media3 reports nothing after this. */
    fun cancel() = transformer.cancel()

    private fun composition(): Composition {
        val items = request.clips.map { clip ->
            val media = MediaItem.Builder()
                .setUri(clip.uri)
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionUs(clip.startUs)
                        .setEndPositionUs(clip.endUs)
                        .build(),
                )
                .build()
            EditedMediaItem.Builder(media).setEffects(Effects(emptyList(), videoEffects())).build()
        }
        return Composition.Builder(EditedMediaItemSequence.withAudioAndVideoFrom(items))
            .setEffects(Effects(audioToOutputFormat(), emptyList()))
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
            .build()
    }

    private fun videoEffects() = listOf(
        FrameDropEffect.createDefaultFrameDropEffect(request.frameRate),
        Presentation.createForWidthAndHeight(request.width, request.height, Presentation.LAYOUT_SCALE_TO_FIT),
    )

    /** The planned rate in stereo, whatever the first clip had (later clips are converted to it by Media3). */
    private fun audioToOutputFormat(): List<AudioProcessor> {
        val resample = SonicAudioProcessor().apply { setOutputSampleRateHz(request.audioSampleRate) }
        val stereo = ChannelMixingAudioProcessor().apply {
            // Mono plays on both sides at full level, as ffmpeg upmixes it;
            // surround folds down keeping its power.
            putChannelMixingMatrix(ChannelMixingMatrix.createForConstantGain(1, 2))
            putChannelMixingMatrix(ChannelMixingMatrix.createForConstantGain(2, 2))
            for (channels in 3..MAX_INPUT_CHANNELS) {
                putChannelMixingMatrix(ChannelMixingMatrix.createForConstantPower(channels, 2))
            }
        }
        return listOf(resample, stereo)
    }

    private companion object {
        /** The most channels Media3 has a default stereo fold-down for (5.1). */
        const val MAX_INPUT_CHANNELS = 6
    }
}
