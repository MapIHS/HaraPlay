package com.mmi.haraplay.media

import java.nio.charset.Charset
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Fixtures are made the way the bug makes them: text encoded in one
 * charset, its bytes then read as Latin-1 (Android 9's scanner, ID3
 * "ISO-8859-1" frames) or Windows-1252.
 */
class TextRepairTest {

    /** Windows-1252 as Windows reads it: its five undefined bytes become U+0081 …, as in Latin-1. */
    private fun garble(text: String, charset: String, readAs: String = "ISO-8859-1"): String {
        val bytes = text.toByteArray(Charset.forName(charset))
        if (readAs != "windows-1252") return String(bytes, Charset.forName(readAs))
        return bytes.joinToString("") { b ->
            val v = b.toInt() and 0xFF
            if (v in setOf(0x81, 0x8D, 0x8F, 0x90, 0x9D)) v.toChar().toString()
            else String(byteArrayOf(b), Charset.forName("windows-1252"))
        }
    }

    private fun assertRepaired(original: String, charset: String, readAs: String = "ISO-8859-1") {
        val garbled = garble(original, charset, readAs)
        assertEquals("$charset read as $readAs", original, TextRepair.repair(garbled))
    }

    private fun assertUnchanged(text: String) =
        assertEquals(text, TextRepair.repair(text))

    @Test
    fun `the reported song - UTF-8 read as Latin-1`() {
        assertRepaired("五等分の花嫁～ありがとうの花～", "UTF-8")
        assertRepaired("五等分の軌跡 EP", "UTF-8")
    }

    @Test
    fun `UTF-8 read as Windows-1252, and accented Latin text`() {
        assertRepaired("五等分の花嫁", "UTF-8", "windows-1252")
        assertRepaired("Beyoncé – Déjà Vu", "UTF-8", "windows-1252")
        assertRepaired("Sigur Rós", "UTF-8")
    }

    @Test
    fun `Shift-JIS (CP932) and EUC-JP`() {
        assertRepaired("五等分の花嫁", "windows-31j")
        assertRepaired("ありがとう ～君へ～", "windows-31j")
        assertRepaired("表現者 ソング", "windows-31j") // trail bytes 0x5C
        assertRepaired("五等分の花嫁", "EUC-JP")
        assertRepaired("恋のうた", "windows-31j", "windows-1252")
    }

    @Test
    fun `EUC-KR`() {
        assertRepaired("안녕하세요", "EUC-KR")
        assertRepaired("빌런 Villain", "EUC-KR")
    }

    @Test
    fun `GBK and Big5, decided by the file name when both read plausibly`() {
        val gbk = garble("你好世界", "GBK")
        assertEquals("你好世界", TextRepair.repair(gbk, hint = "你好世界.mp3"))
        val big5 = garble("繁體中文歌曲", "Big5")
        assertEquals("繁體中文歌曲", TextRepair.repair(big5, hint = "01 繁體中文歌曲.mp3"))
    }

    @Test
    fun `ambiguous without a hint stays unchanged rather than guessed`() {
        val gbk = garble("你好世界", "GBK")
        val repaired = TextRepair.repair(gbk)
        // Either the right text (only one reading was plausible) or no change.
        assert(repaired == "你好世界" || repaired == gbk) { repaired }
    }

    @Test
    fun `correct titles are never altered`() {
        listOf(
            "五等分の花嫁～ありがとうの花～", "少女A (Cover)", "빌런 / Villain", "你好世界",
            "Beyoncé", "Señorita", "Mötley Crüe", "Ölfarbe", "Café del Mar",
            "Zürich", "Ça plane pour moi", "Sigur Rós – Hoppípolla", "Björk - Jóga",
            "Ænima", "déjà vu", "Œuvre", "naïve", "Él", "Ñoño", "São Paulo",
            "Hello World", "Track 01", "AC/DC - T.N.T.", "", "  ",
            "Ğüneş", "Łódź", "Dvořák",
        ).forEach(::assertUnchanged)
    }

    @Test
    fun `text that only one byte off would make plausible stays unchanged`() {
        // One high byte: never enough to decide.
        assertUnchanged("Café")
        // Latin letters around a would-be CJK character.
        assertUnchanged("Señorita Mañana")
    }

    @Test
    fun `single-byte form - correct CJK text has none`() {
        assertEquals(null, TextRepair.singleByteForm("五等分"))
        assertEquals(2, TextRepair.singleByteForm("é’")!!.size)
        // A replacement character means the bytes are already lost.
        assertEquals(null, TextRepair.singleByteForm("ä�"))
    }

    @Test
    fun `wrong tables are not taken for the right one`() {
        // GBK and EUC-JP text read as EUC-KR gives a Hangul-Han mix.
        assertEquals("五等分の花嫁", TextRepair.repair(garble("五等分の花嫁", "EUC-JP")))
        val gbk = garble("你好世界", "GBK")
        assert(TextRepair.repair(gbk).none { it.code in 0xAC00..0xD7A3 })
    }
}
