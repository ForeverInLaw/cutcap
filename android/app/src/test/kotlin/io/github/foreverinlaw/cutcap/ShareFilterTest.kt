package io.github.foreverinlaw.cutcap

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ShareFilterTest {
    private val own = setOf("io.github.foreverinlaw.cutcap.flutter.image_provider")

    private fun accepts(scheme: String?, authority: String?, readGranted: Boolean = true) =
        ShareFilter.accepts(scheme, authority, readGranted, own::contains)

    @Test
    fun takesAGrantedVideoFromAnotherApp() {
        assertTrue(accepts("content", "com.google.android.apps.photos.contentprovider"))
        assertTrue(accepts("content", "media"))
    }

    @Test
    fun refusesFileUris() {
        assertFalse(accepts("file", null))
        assertFalse(accepts("file", ""))
    }

    @Test
    fun refusesOtherSchemes() {
        assertFalse(accepts("https", "example.com"))
        assertFalse(accepts(null, null))
    }

    @Test
    fun refusesCutcapsOwnProviders() {
        assertFalse(accepts("content", own.first()))
        assertFalse(accepts("content", "10@${own.first()}"))
    }

    @Test
    fun refusesUrisTheSenderDidNotGrant() {
        assertFalse(accepts("content", "media", readGranted = false))
    }
}
