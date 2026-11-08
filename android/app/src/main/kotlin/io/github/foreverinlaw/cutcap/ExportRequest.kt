package io.github.foreverinlaw.cutcap

/**
 * One export as the Dart side plans it (`AndroidExportEngine`): the
 * `ExportPlan` reduced to what Media3 needs. Sizes, rate and bitrate are
 * the first clip's, by the spec's output rules; each clip is the span of
 * its source to decode.
 */
data class ExportRequest(
    /** File name in Movies/cutcap; MediaStore makes it unique and valid. */
    val name: String,
    val width: Int,
    val height: Int,
    val frameRateNumerator: Int,
    val frameRateDenominator: Int,
    /** Target video bitrate in bits per second. */
    val videoBitRate: Int,
    val clips: List<Clip>,
) {
    /** A source URI and the span of it to export, in microseconds. */
    data class Clip(val uri: String, val startUs: Long, val endUs: Long)

    /** Output frames per second. */
    val frameRate: Float get() = frameRateNumerator.toFloat() / frameRateDenominator

    companion object {
        /**
         * Reads the channel map; throws [IllegalArgumentException] naming
         * what is missing or out of range.
         */
        fun from(map: Map<*, *>): ExportRequest {
            fun int(key: String) = (map[key] as? Number)?.toInt()
                ?: throw IllegalArgumentException("$key missing")
            val clips = (map["clips"] as? List<*>)?.map { clip ->
                val fields = clip as? Map<*, *> ?: throw IllegalArgumentException("clip is no map")
                fun long(key: String) = (fields[key] as? Number)?.toLong()
                    ?: throw IllegalArgumentException("clip $key missing")
                Clip(
                    uri = fields["uri"] as? String ?: throw IllegalArgumentException("clip uri missing"),
                    startUs = long("startUs"),
                    endUs = long("endUs"),
                )
            } ?: throw IllegalArgumentException("clips missing")
            return ExportRequest(
                name = (map["name"] as? String)?.takeIf(String::isNotBlank)
                    ?: throw IllegalArgumentException("name missing"),
                width = int("width"),
                height = int("height"),
                frameRateNumerator = int("frameRateNumerator"),
                frameRateDenominator = int("frameRateDenominator"),
                videoBitRate = int("videoBitRate"),
                clips = clips,
            ).also(::requireValid)
        }

        private fun requireValid(request: ExportRequest) = with(request) {
            require(clips.isNotEmpty()) { "no clips" }
            require(width > 0 && height > 0 && width % 2 == 0 && height % 2 == 0) {
                "size ${width}x$height is not positive and even"
            }
            require(frameRateNumerator > 0 && frameRateDenominator > 0) { "frame rate not positive" }
            require(videoBitRate > 0) { "bitrate not positive" }
            clips.forEach { require(it.startUs >= 0 && it.endUs > it.startUs) { "empty span in ${it.uri}" } }
        }
    }
}
