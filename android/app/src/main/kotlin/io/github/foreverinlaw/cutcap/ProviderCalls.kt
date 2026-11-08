package io.github.foreverinlaw.cutcap

import android.util.Log
import java.io.FileNotFoundException

// Calls into content providers. Providers belong to other apps, so they may
// refuse a call in the documented ways (orNullIfRefused) or throw anything
// at all; neither may take cutcap down (guarded).

/**
 * [block], or null (logged) when a content provider refuses it: the video
 * is gone ([FileNotFoundException]), the read grant was lost
 * ([SecurityException]), or the provider does not know the URI or a
 * column ([IllegalArgumentException]). Anything else propagates to the
 * [guarded] entry point around the call.
 */
inline fun <T> orNullIfRefused(what: String, block: () -> T?): T? = try {
    block()
} catch (error: FileNotFoundException) {
    refused(what, error)
} catch (error: SecurityException) {
    refused(what, error)
} catch (error: IllegalArgumentException) {
    refused(what, error)
}

/** Logs why a provider refused [what]; always null. */
fun refused(what: String, error: Exception): Nothing? {
    warn("Provider refused to $what: $error")
    return null
}

/**
 * Runs [work] at an entry point that reaches into content providers (a
 * channel call on a worker thread, a share, a picker result), so that no
 * exception from a misbehaving provider escapes it: [work]'s value, or the
 * exception it threw, after [log]ging it. The caller reports the failure
 * (an error to Dart, the original URI); it is never swallowed. Errors such
 * as running out of memory still propagate.
 */
inline fun <T> guarded(what: String, log: (String) -> Unit = ::warn, work: () -> T): Result<T> = try {
    Result.success(work())
} catch (error: Exception) {
    log("$what failed: $error")
    Result.failure(error)
}

fun warn(message: String) {
    Log.w("cutcap", message)
}
