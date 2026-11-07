package io.github.foreverinlaw.cutcap

/**
 * Which videos shared into cutcap it may read. A share is read with
 * cutcap's own access, so a sender could otherwise point it at cutcap's
 * private files (`file://`, or cutcap's own providers) or at media the
 * sender itself cannot read (a confused deputy). Only `content://` URIs
 * the sender granted read access to, from someone else's provider, pass.
 */
object ShareFilter {
    /**
     * Whether a shared URI with [scheme] and [authority] may be read.
     * [readGranted] is whether the share intent grants read access;
     * [isOwnAuthority] tells cutcap's own provider authorities.
     */
    fun accepts(
        scheme: String?,
        authority: String?,
        readGranted: Boolean,
        isOwnAuthority: (String) -> Boolean,
    ): Boolean {
        if (scheme != "content" || authority.isNullOrEmpty() || !readGranted) return false
        // "10@authority" addresses the same provider in another user.
        return !isOwnAuthority(authority.substringAfterLast('@'))
    }
}
