package com.haiskynology.aurai

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Small, dependency-free OOXML writers for the script workspace. */
object OfficeDocuments {
    private const val WORD = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    private const val SHEET = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    private const val REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    private const val PACKAGE_REL = "http://schemas.openxmlformats.org/package/2006/relationships"
    private const val XML = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"

    fun word(file: File, document: JSONObject) {
        val body = StringBuilder()
        body.append(paragraph(document.getString("title"), 36, true))
        val blocks = document.getJSONArray("blocks")
        for (index in 0 until blocks.length()) {
            val block = blocks.getJSONObject(index)
            when (block.getString("type")) {
                "heading" -> {
                    val level = block.getInt("level")
                    require(level in 1..6) { "标题层级必须为 1–6" }
                    body.append(paragraph(block.getString("text"), 34 - level * 2, true, level - 1))
                }
                "paragraph" -> body.append(paragraph(block.getString("text")))
                "bullets" -> {
                    val items = block.getJSONArray("items")
                    for (i in 0 until items.length()) body.append(paragraph("• " + items.getString(i)))
                }
                "table" -> {
                    val rows = block.getJSONArray("rows")
                    require(rows.length() > 0) { "表格至少需要一行" }
                    val columns = rows.getJSONArray(0).length()
                    require(columns in 1..20) { "表格列数必须为 1–20" }
                    body.append("<w:tbl><w:tblPr><w:tblW w:w=\"0\" w:type=\"auto\"/><w:tblBorders>")
                    for (edge in listOf("top", "left", "bottom", "right", "insideH", "insideV")) {
                        body.append("<w:$edge w:val=\"single\" w:sz=\"4\" w:color=\"B8B8B8\"/>")
                    }
                    body.append("</w:tblBorders></w:tblPr><w:tblGrid>")
                    repeat(columns) { body.append("<w:gridCol w:w=\"${9360 / columns}\"/>") }
                    body.append("</w:tblGrid>")
                    for (rowIndex in 0 until rows.length()) {
                        val row = rows.getJSONArray(rowIndex)
                        require(row.length() == columns) { "表格各行列数必须相同" }
                        body.append("<w:tr>")
                        for (column in 0 until columns) {
                            body.append("<w:tc><w:tcPr><w:tcW w:w=\"${9360 / columns}\" w:type=\"dxa\"/></w:tcPr>")
                            body.append(paragraph(row.getString(column), bold = rowIndex == 0)).append("</w:tc>")
                        }
                        body.append("</w:tr>")
                    }
                    body.append("</w:tbl><w:p/>")
                }
                else -> error("不支持的文档块：${block.getString("type")}")
            }
        }
        body.append("<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"1273\" w:right=\"1273\" w:bottom=\"1273\" w:left=\"1273\" w:header=\"720\" w:footer=\"720\" w:gutter=\"0\"/></w:sectPr>")
        packageFile(file, mapOf(
            "[Content_Types].xml" to contentTypes(mapOf("/word/document.xml" to "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml")),
            "_rels/.rels" to relationships(listOf(Triple("rId1", "$REL/officeDocument", "word/document.xml"))),
            "word/document.xml" to "$XML<w:document xmlns:w=\"$WORD\"><w:body>$body</w:body></w:document>",
        ))
    }

    fun spreadsheet(file: File, workbook: JSONObject) {
        val sheets = workbook.getJSONArray("sheets")
        require(sheets.length() in 1..100) { "工作表数量必须为 1–100" }
        val entries = linkedMapOf<String, String>()
        val types = linkedMapOf("/xl/workbook.xml" to "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml")
        val relationships = mutableListOf<Triple<String, String, String>>()
        val names = mutableSetOf<String>()
        val sheetList = StringBuilder()
        for (index in 0 until sheets.length()) {
            val sheet = sheets.getJSONObject(index)
            val name = sheet.getString("name")
            require(name.isNotBlank() && name.length <= 31 && name.none { it in "[]:*?/\\" } &&
                !name.startsWith("'") && !name.endsWith("'") && names.add(name.lowercase(java.util.Locale.ROOT))) { "工作表名称无效或重复" }
            val id = index + 1
            sheetList.append("<sheet name=\"${escape(name)}\" sheetId=\"$id\" r:id=\"rId$id\"/>")
            types["/xl/worksheets/sheet$id.xml"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"
            relationships.add(Triple("rId$id", "$REL/worksheet", "worksheets/sheet$id.xml"))
            val rows = sheet.getJSONArray("rows")
            require(rows.length() <= 1_048_576) { "超出 Excel 行数限制" }
            val data = StringBuilder()
            for (r in 0 until rows.length()) {
                val row = rows.getJSONArray(r)
                require(row.length() <= 16384) { "超出 Excel 列数限制" }
                data.append("<row r=\"${r + 1}\">")
                for (c in 0 until row.length()) {
                    val value = row.get(c)
                    val ref = column(c) + (r + 1)
                    data.append(when (value) {
                        JSONObject.NULL -> ""
                        is Boolean -> "<c r=\"$ref\" t=\"b\"><v>${if (value) 1 else 0}</v></c>"
                        is Number -> {
                            require(value.toDouble().isFinite()) { "数字必须是有限值" }
                            "<c r=\"$ref\"><v>$value</v></c>"
                        }
                        is String -> {
                            require(value.length <= 32767) { "单元格文字超过 Excel 限制" }
                            "<c r=\"$ref\" t=\"inlineStr\"><is><t xml:space=\"preserve\">${escape(value)}</t></is></c>"
                        }
                        is JSONObject -> "<c r=\"$ref\"><f>${escape(value.getString("formula"))}</f></c>"
                        else -> error("不支持的单元格内容")
                    })
                }
                data.append("</row>")
            }
            entries["xl/worksheets/sheet$id.xml"] = "$XML<worksheet xmlns=\"$SHEET\"><sheetData>$data</sheetData></worksheet>"
        }
        entries["[Content_Types].xml"] = contentTypes(types)
        entries["_rels/.rels"] = relationships(listOf(Triple("rId1", "$REL/officeDocument", "xl/workbook.xml")))
        entries["xl/_rels/workbook.xml.rels"] = relationships(relationships)
        entries["xl/workbook.xml"] = "$XML<workbook xmlns=\"$SHEET\" xmlns:r=\"$REL\"><sheets>$sheetList</sheets><calcPr fullCalcOnLoad=\"1\"/></workbook>"
        packageFile(file, entries)
    }

    private fun paragraph(text: String, size: Int = 22, bold: Boolean = false, outline: Int? = null): String {
        val properties = "<w:pPr><w:spacing w:after=\"160\" w:line=\"300\" w:lineRule=\"auto\"/>" +
            (outline?.let { "<w:outlineLvl w:val=\"$it\"/>" } ?: "") + "</w:pPr>"
        val runs = text.split('\n').joinToString("<w:br/>") { "<w:t xml:space=\"preserve\">${escape(it)}</w:t>" }
        return "<w:p>$properties<w:r><w:rPr><w:rFonts w:ascii=\"Calibri\" w:hAnsi=\"Calibri\" w:eastAsia=\"宋体\"/>" +
            (if (bold) "<w:b/>" else "") + "<w:sz w:val=\"$size\"/></w:rPr>$runs</w:r></w:p>"
    }

    private fun column(index: Int): String {
        var number = index + 1
        var result = ""
        while (number > 0) { number--; result = ('A'.code + number % 26).toChar() + result; number /= 26 }
        return result
    }

    private fun escape(text: String): String {
        require(text.codePoints().allMatch { it == 9 || it == 10 || it == 13 || it in 0x20..0xD7FF || it in 0xE000..0xFFFD || it in 0x10000..0x10FFFF }) { "内容含无效 XML 字符" }
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&apos;")
    }

    private fun contentTypes(types: Map<String, String>): String =
        "$XML<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
            types.entries.joinToString("") { "<Override PartName=\"${it.key}\" ContentType=\"${it.value}\"/>" } + "</Types>"

    private fun relationships(items: List<Triple<String, String, String>>): String =
        "$XML<Relationships xmlns=\"$PACKAGE_REL\">" + items.joinToString("") {
            "<Relationship Id=\"${it.first}\" Type=\"${it.second}\" Target=\"${it.third}\"/>"
        } + "</Relationships>"

    private fun packageFile(file: File, entries: Map<String, String>) {
        ZipOutputStream(file.outputStream()).use { zip ->
            entries.forEach { (name, content) ->
                zip.putNextEntry(ZipEntry(name)); zip.write(content.toByteArray(Charsets.UTF_8)); zip.closeEntry()
            }
        }
    }
}
