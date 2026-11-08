package io.github.foreverinlaw.cutcap

/** What a running export reports to Dart (`AndroidExportEngine`), as [toMap]. */
sealed class ExportEvent {
    abstract fun toMap(): Map<String, Any?>

    /** [fraction] of the output written, 0 to 1. */
    data class Progress(val fraction: Double) : ExportEvent() {
        override fun toMap() = mapOf("event" to "progress", "fraction" to fraction)
    }

    /** How an export ended; the last event of every export. */
    sealed class Outcome : ExportEvent()

    /** The video is in Movies/cutcap at [uri], under the [name] MediaStore gave it. */
    data class Succeeded(val uri: String, val name: String?) : Outcome() {
        override fun toMap() = mapOf("event" to "succeeded", "uri" to uri, "name" to name)
    }

    /** Nothing was saved; [reason] is English technical text for the details line. */
    data class Failed(val reason: String) : Outcome() {
        override fun toMap() = mapOf("event" to "failed", "reason" to reason)

        companion object {
            /**
             * [headline], then each distinct message down [error]'s cause
             * chain, so the reason names what failed and why (e.g. Media3's
             * error code, then the codec's own words).
             */
            fun of(headline: String, error: Throwable): Failed {
                val messages = generateSequence(error) { it.cause }
                    .take(MAX_CAUSES)
                    .mapNotNull { it.message?.trim()?.takeIf(String::isNotEmpty) ?: it.javaClass.simpleName }
                    .distinct()
                    .toList()
                return Failed((listOf(headline) + messages).joinToString(": "))
            }

            private const val MAX_CAUSES = 4
        }
    }

    data object Cancelled : Outcome() {
        override fun toMap() = mapOf("event" to "cancelled")
    }
}
