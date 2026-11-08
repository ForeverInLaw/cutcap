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
        assertEquals(
            mapOf("event" to "failed", "kind" to "cannotWrite", "detail" to "disk full"),
            ExportEvent.Failed(ExportEvent.Failed.Kind.CANNOT_WRITE, "disk full").toMap(),
        )
        assertEquals(
            mapOf("event" to "failed", "kind" to "timeLimit", "detail" to null),
            ExportEvent.Failed(ExportEvent.Failed.Kind.TIME_LIMIT).toMap(),
        )
        assertEquals(mapOf("event" to "cancelled"), ExportEvent.Cancelled.toMap())
    }

    @Test
    fun aFailureDetailNamesItsCodeAndEachCause() {
        val error = RuntimeException(
            "Asset loader error",
            FileNotFoundException("content://media/external/video/media/1: open failed: ENOENT"),
        )

        val failed = ExportEvent.Failed.of(ExportEvent.Failed.Kind.FAILED, error, code = "ERROR_CODE_IO_FILE_NOT_FOUND")

        assertEquals(ExportEvent.Failed.Kind.FAILED, failed.kind)
        assertEquals(
            "ERROR_CODE_IO_FILE_NOT_FOUND: Asset loader error: " +
                "content://media/external/video/media/1: open failed: ENOENT",
            failed.detail,
        )
    }

    @Test
    fun aCauseWithoutMessageIsNamedByItsType() {
        val error = IllegalStateException("Codec failed", IllegalArgumentException())

        assertEquals(
            "Codec failed: IllegalArgumentException",
            ExportEvent.Failed.of(ExportEvent.Failed.Kind.CANNOT_START, error).detail,
        )
    }
}
