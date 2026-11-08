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

    /**
     * Nothing was saved, for the reason [kind] names; [detail] is the
     * technical account (Media3's error code, the causes' own words),
     * untranslated, when there is one.
     */
    data class Failed(val kind: Kind, val detail: String? = null) : Outcome() {
        override fun toMap() = mapOf("event" to "failed", "kind" to kind.wireName, "detail" to detail)

        /** The Android cases of Dart's `ExportFailure`, by its value names. */
        enum class Kind(val wireName: String) {
            /** Media3 or the service did not start. */
            CANNOT_START("cannotStart"),

            /** The video could not be saved to Movies/cutcap. */
            CANNOT_WRITE("cannotWrite"),

            /** Android stopped the service before the export was done. */
            STOPPED("stopped"),

            /** Android 15+ ran out of the day's time for media processing. */
            TIME_LIMIT("timeLimit"),

            /** Media3 ran and failed. */
            FAILED("failed"),
        }

        companion object {
            /**
             * A [kind] failure whose detail is [code] (when given), then each
             * distinct message down [error]'s cause chain, so it names what
             * failed and why (e.g. Media3's error code, then the codec's own
             * words).
             */
            fun of(kind: Kind, error: Throwable, code: String? = null): Failed {
                val messages = generateSequence(error) { it.cause }
                    .take(MAX_CAUSES)
                    .mapNotNull { it.message?.trim()?.takeIf(String::isNotEmpty) ?: it.javaClass.simpleName }
                    .distinct()
                    .toList()
                return Failed(kind, (listOfNotNull(code) + messages).joinToString(": "))
            }

            private const val MAX_CAUSES = 4
        }
    }

    data object Cancelled : Outcome() {
        override fun toMap() = mapOf("event" to "cancelled")
    }
}
