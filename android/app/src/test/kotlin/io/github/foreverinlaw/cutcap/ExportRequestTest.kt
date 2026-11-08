package io.github.foreverinlaw.cutcap

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ExportRequestTest {
    /** What `AndroidExportEngine` sends for two clips exported at 29.97 fps. */
    private fun channelMap(
        width: Any? = 1280,
        clips: Any? = listOf(
            mapOf("uri" to "content://media/external/video/media/1", "startUs" to 983334, "endUs" to 1983334L),
            mapOf("uri" to "content://media/external/video/media/2", "startUs" to 0, "endUs" to 400000),
        ),
    ): Map<String, Any?> = mapOf(
        "name" to "beach-cut.mp4",
        "width" to width,
        "height" to 720,
        "frameRateNumerator" to 30000,
        "frameRateDenominator" to 1001,
        "videoBitRate" to 8000000,
        "audioSampleRate" to 48000,
        "audioBitRate" to 192000,
        "clips" to clips,
    )

    @Test
    fun readsThePlanAsDartSendsIt() {
        val request = ExportRequest.from(channelMap())

        assertEquals("beach-cut.mp4", request.name)
        assertEquals(1280 to 720, request.width to request.height)
        assertEquals(8000000, request.videoBitRate)
        assertEquals(48000 to 192000, request.audioSampleRate to request.audioBitRate)
        assertEquals(
            listOf(
                ExportRequest.Clip("content://media/external/video/media/1", 983334, 1983334),
                ExportRequest.Clip("content://media/external/video/media/2", 0, 400000),
            ),
            request.clips,
        )
    }

    @Test
    fun givesTheFrameRateMedia3Drops() {
        assertEquals(29.97f, ExportRequest.from(channelMap()).frameRate, 0.001f)
    }

    @Test
    fun refusesWhatMedia3CannotEncode() {
        assertThrows(IllegalArgumentException::class.java) { ExportRequest.from(channelMap(width = 1279)) }
        assertThrows(IllegalArgumentException::class.java) { ExportRequest.from(channelMap(clips = emptyList<Any>())) }
        assertThrows(IllegalArgumentException::class.java) {
            ExportRequest.from(
                channelMap(clips = listOf(mapOf("uri" to "content://x", "startUs" to 500, "endUs" to 500))),
            )
        }
    }

    @Test
    fun namesWhatIsMissing() {
        val error = assertThrows(IllegalArgumentException::class.java) { ExportRequest.from(channelMap(width = null)) }
        assertEquals("width missing", error.message)
    }
}
