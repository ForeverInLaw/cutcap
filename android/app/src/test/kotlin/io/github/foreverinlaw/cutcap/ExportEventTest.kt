package io.github.foreverinlaw.cutcap

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.FileNotFoundException

class ExportEventTest {
    @Test
    fun sendsEachEventInTheShapeDartReads() {
        assertEquals(mapOf("event" to "progress", "fraction" to 0.5), ExportEvent.Progress(0.5).toMap())
        assertEquals(
            mapOf("event" to "succeeded", "uri" to "content://media/external/video/media/9", "name" to "a (1).mp4"),
            ExportEvent.Succeeded("content://media/external/video/media/9", "a (1).mp4").toMap(),
        )
        assertEquals(mapOf("event" to "failed", "reason" to "disk full"), ExportEvent.Failed("disk full").toMap())
        assertEquals(mapOf("event" to "cancelled"), ExportEvent.Cancelled.toMap())
    }

    @Test
    fun aFailureNamesItsCodeAndEachCause() {
        val error = RuntimeException(
            "Asset loader error",
            FileNotFoundException("content://media/external/video/media/1: open failed: ENOENT"),
        )

        assertEquals(
            "ERROR_CODE_IO_FILE_NOT_FOUND: Asset loader error: " +
                "content://media/external/video/media/1: open failed: ENOENT",
            ExportEvent.Failed.of("ERROR_CODE_IO_FILE_NOT_FOUND", error).reason,
        )
    }

    @Test
    fun aCauseWithoutMessageIsNamedByItsType() {
        val error = IllegalStateException("Codec failed", IllegalArgumentException())

        assertEquals(
            "Media3 did not start: Codec failed: IllegalArgumentException",
            ExportEvent.Failed.of("Media3 did not start", error).reason,
        )
    }
}
