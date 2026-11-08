package io.github.foreverinlaw.cutcap

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ProviderCallsTest {
    private val logged = mutableListOf<String>()
    private val log: (String) -> Unit = { logged += it }

    @Test
    fun passesTheValueOfWorkThatSucceeds() {
        assertEquals(Result.success(42), guarded("answering", log) { 42 })
        assertTrue(logged.isEmpty())
    }

    @Test
    fun turnsAnythingAProviderThrowsIntoALoggedFailure() {
        for (thrown in listOf(IllegalStateException("cursor closed"), UnsupportedOperationException(), NullPointerException())) {
            val outcome = guarded("query content://other.app/video/1", log) { throw thrown }

            assertEquals(thrown, outcome.exceptionOrNull())
        }
        assertEquals(3, logged.size)
        assertTrue(logged.first().startsWith("query content://other.app/video/1 failed: java.lang.IllegalStateException"))
    }

    @Test
    fun letsErrorsThrough() {
        assertThrows(StackOverflowError::class.java) {
            guarded("recursing", log) { throw StackOverflowError() }
        }
    }
}
