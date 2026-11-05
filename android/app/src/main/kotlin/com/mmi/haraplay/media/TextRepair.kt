package com.mmi.haraplay.media

import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.Charset
import java.nio.charset.CodingErrorAction

/**
 * Repairs mojibake: text whose bytes were in UTF-8, Shift-JIS (CP932),
 * EUC-JP, GBK, Big5 or EUC-KR but were read as Latin-1 / Windows-1252
 * (Android 9's media scanner, ID3 frames that claim ISO-8859-1, ID3v1).
 *
 * A repair is made only when the text can be turned back into its
 * single-byte form, one encoding decodes those bytes without errors, and
 * the result is plausible for that encoding. Anything else, including
 * every correct title, is returned unchanged.
 */
object TextRepair {

    /** [text] repaired, or [text] itself. [hint] (e.g. the file name) breaks ties. */
    fun repair(text: String, hint: String? = null): String {
        val bytes = singleByteForm(text) ?: return text
        if (bytes.count { it.toInt() and 0xFF >= 0x80 } < 2) return text

        // UTF-8 is self-checking: a valid multi-byte sequence almost never
        // happens by chance in real Latin-1 text.
        decode(bytes, UTF_8)?.let { utf8 ->
            if (utf8 != text && isClean(utf8)) return utf8
        }

        val candidates = LinkedHashMap<String, Script>()
        for ((charset, script) in cjkCharsets) {
            val decoded = decode(bytes, charset) ?: continue
            if (plausibleCjk(decoded, script)) candidates.putIfAbsent(decoded, script)
        }
        if (candidates.isEmpty()) return text
        if (candidates.size == 1) return candidates.keys.first()

        // Several encodings read it plausibly: the hint decides, else a
        // script only one of them produced (kana, Hangul).
        if (hint != null) {
            candidates.keys.firstOrNull { hint.contains(it) }?.let { return it }
        }
        val kana = candidates.keys.filter { it.any(::isKana) }
        if (kana.size == 1) return kana.first()
        val hangul = candidates.keys.filter { it.any(::isHangul) }
        if (hangul.size == 1) return hangul.first()
        return text
    }

    /** What a script check looks for. */
    enum class Script { JAPANESE, CHINESE, KOREAN }

    private val UTF_8: Charset = Charsets.UTF_8

    private val cjkCharsets: List<Pair<Charset, Script>> by lazy {
        listOfNotNull(
            charset("windows-31j", "Shift_JIS")?.let { it to Script.JAPANESE },
            charset("EUC-JP")?.let { it to Script.JAPANESE },
            charset("GBK")?.let { it to Script.CHINESE },
            charset("Big5")?.let { it to Script.CHINESE },
            charset("EUC-KR")?.let { it to Script.KOREAN },
        )
    }

    private fun charset(vararg names: String): Charset? {
        for (name in names) {
            try {
                if (Charset.isSupported(name)) return Charset.forName(name)
            } catch (e: IllegalArgumentException) {
                // Unknown name on this device: try the next.
            }
        }
        return null
    }

    /**
     * The bytes [text] came from if it was read as Latin-1 (or
     * Windows-1252, whose 0x80-0x9F are letters and punctuation), or null
     * when it has a character neither can produce (then it isn't
     * single-byte mojibake, e.g. correct Japanese).
     */
    fun singleByteForm(text: String): ByteArray? {
        val out = ByteArray(text.length)
        for ((i, ch) in text.withIndex()) {
            val code = ch.code
            out[i] = when {
                code <= 0xFF -> code.toByte()
                else -> (cp1252Reverse[ch] ?: return null).toByte()
            }
        }
        return out
    }

    private val cp1252Reverse: Map<Char, Int> by lazy {
        val cp1252 = charset("windows-1252") ?: return@lazy emptyMap()
        val map = HashMap<Char, Int>()
        for (b in 0x80..0x9F) {
            val s = String(byteArrayOf(b.toByte()), cp1252)
            // Undefined bytes (0x81, 0x8D, …) decode to U+FFFD here; real
            // mojibake has U+0081 … for them, which maps back directly.
            if (s.length == 1 && s[0].code > 0xFF && s[0] != '\uFFFD') map[s[0]] = b
        }
        map
    }

    private fun decode(bytes: ByteArray, charset: Charset): String? = try {
        charset.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes))
            .toString()
    } catch (e: CharacterCodingException) {
        null
    }

    /** No control, replacement, private-use or unpaired surrogate characters. */
    private fun isClean(text: String): Boolean {
        var i = 0
        while (i < text.length) {
            val cp = text.codePointAt(i)
            if (cp < 0x20 && cp != '\t'.code) return false
            if (cp in 0x7F..0x9F || cp == 0xFFFD || cp in 0xE000..0xF8FF) return false
            if (cp in 0xD800..0xDFFF) return false
            if (Character.getType(cp) == Character.UNASSIGNED.toInt()) return false
            i += Character.charCount(cp)
        }
        return true
    }

    private fun plausibleCjk(text: String, script: Script): Boolean {
        if (!isClean(text)) return false
        var cjk = 0
        val chars = text.codePoints().toArray()
        for ((i, cp) in chars.withIndex()) {
            if (cp < 0x80) continue
            val letter = isHan(cp) || isKana(cp) || isHangul(cp)
            if (!letter && !isCjkPunctuationOrSymbol(cp)) return false
            if (!letter) continue
            cjk++
            // "Se镲rita" (GBK reading "Señorita"): a CJK letter inside a
            // Latin word is a misreading of an accented letter.
            val before = chars.getOrNull(i - 1)
            val after = chars.getOrNull(i + 1)
            if (before != null && after != null && isAsciiLetter(before) && isAsciiLetter(after)) {
                return false
            }
        }
        if (cjk < 2) return false
        // Each script on its own: a Hangul-Han mix, or kana in "Chinese",
        // is what reading bytes with the wrong table looks like.
        return when (script) {
            Script.JAPANESE -> chars.none(::isHangul)
            Script.CHINESE -> chars.none { isHangul(it) || isKana(it) }
            Script.KOREAN -> chars.none { isHan(it) || isKana(it) }
        }
    }

    private fun isAsciiLetter(cp: Int) = cp in 'a'.code..'z'.code || cp in 'A'.code..'Z'.code

    fun isKana(cp: Int) = cp in 0x3040..0x30FF || cp in 0x31F0..0x31FF || cp in 0xFF66..0xFF9F
    private fun isKana(ch: Char) = isKana(ch.code)

    fun isHan(cp: Int) = cp in 0x4E00..0x9FFF || cp in 0x3400..0x4DBF ||
        cp in 0xF900..0xFAFF || cp in 0x20000..0x2FFFF || cp == 0x3005 || cp == 0x3007

    /** Hangul syllables only: lone jamo don't make a title. */
    fun isHangul(cp: Int) = cp in 0xAC00..0xD7A3
    private fun isHangul(ch: Char) = isHangul(ch.code)

    /** Punctuation and symbols these encodings carry: 「」、。・～ ★ ♪ → ×, fullwidth forms, Greek and Cyrillic. */
    private fun isCjkPunctuationOrSymbol(cp: Int) =
        cp in 0x3000..0x303F || cp in 0xFF00..0xFFEF || cp in 0x2010..0x2BFF ||
            cp in 0x3200..0x33FF || cp in 0x2E80..0x2FDF || cp in 0x0391..0x03C9 ||
            cp in 0x0401..0x0451 || cp == 0x00A7 || cp == 0x00A8 || cp == 0x00B0 ||
            cp == 0x00B1 || cp == 0x00B4 || cp == 0x00B6 || cp == 0x00B7 ||
            cp == 0x00D7 || cp == 0x00F7
}
