import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// One worksheet. Cells may be `String`, `num`, `DateTime`, `bool` or null.
class XlsxSheet {
  final String name;
  final List<String> headers;
  final List<List<Object?>> rows;

  /// Optional column widths (in Excel "characters").
  final List<double>? widths;

  XlsxSheet({
    required this.name,
    required this.headers,
    required this.rows,
    this.widths,
  });
}

/// Minimal, dependency-light .xlsx (Office Open XML) writer.
///
/// Produces real numeric / date cells so users can pivot, chart and filter
/// in Excel, Google Sheets or Numbers. Header row is bold, frozen and has
/// an auto-filter.
class XlsxWriter {
  // Style indices in styles.xml (cellXfs).
  static const int _styleHeader = 1;
  static const int _styleDate = 2;
  static const int _styleDecimal = 3;

  static Uint8List build(List<XlsxSheet> sheets) {
    if (sheets.isEmpty) {
      throw ArgumentError('An xlsx workbook needs at least one sheet');
    }
    final names = _uniqueSheetNames(sheets.map((s) => s.name).toList());
    final archive = Archive();

    void add(String path, String xml) {
      archive.addFile(ArchiveFile.bytes(path, utf8.encode(xml)));
    }

    add('[Content_Types].xml', _contentTypes(sheets.length));
    add('_rels/.rels', _rootRels);
    add('docProps/app.xml', _appXml);
    add('docProps/core.xml', _coreXml());
    add('xl/workbook.xml', _workbook(names));
    add('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length));
    add('xl/styles.xml', _styles);
    for (var i = 0; i < sheets.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i]));
    }

    return ZipEncoder().encodeBytes(archive);
  }

  // ---------------------------------------------------------------- helpers

  static List<String> _uniqueSheetNames(List<String> raw) {
    final used = <String>{};
    final out = <String>[];
    for (final r in raw) {
      var base = r.replaceAll(RegExp(r'[\[\]\*\?/\\:]'), ' ').trim();
      if (base.isEmpty) base = 'Sheet';
      if (base.length > 31) base = base.substring(0, 31);
      var name = base;
      var n = 2;
      while (used.contains(name.toLowerCase())) {
        final suffix = ' ($n)';
        name = (base.length + suffix.length > 31
                ? base.substring(0, 31 - suffix.length)
                : base) +
            suffix;
        n++;
      }
      used.add(name.toLowerCase());
      out.add(name);
    }
    return out;
  }

  static String colName(int index) {
    // 0 -> A, 25 -> Z, 26 -> AA
    var n = index + 1;
    var s = '';
    while (n > 0) {
      final m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  static String _esc(String v) {
    // Strip characters that are illegal in XML 1.0.
    final clean = v.replaceAll(
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    return clean
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  /// Excel serial date (days since 1899-12-30), using local wall-clock time.
  static double excelDate(DateTime d) {
    final local = d.toLocal();
    final asUtc = DateTime.utc(local.year, local.month, local.day, local.hour,
        local.minute, local.second);
    return asUtc.difference(DateTime.utc(1899, 12, 30)).inSeconds / 86400.0;
  }

  static String _cell(String ref, Object? v, {bool header = false}) {
    if (v == null) return '';
    if (header) {
      return '<c r="$ref" t="inlineStr" s="$_styleHeader"><is><t>${_esc(v.toString())}</t></is></c>';
    }
    if (v is DateTime) {
      return '<c r="$ref" s="$_styleDate"><v>${excelDate(v)}</v></c>';
    }
    if (v is bool) {
      return '<c r="$ref" t="b"><v>${v ? 1 : 0}</v></c>';
    }
    if (v is num) {
      if (v.isNaN || v.isInfinite) return '';
      final isInt = v == v.roundToDouble();
      final style = isInt ? '' : ' s="$_styleDecimal"';
      return '<c r="$ref"$style><v>${isInt ? v.toInt() : v}</v></c>';
    }
    final s = v.toString();
    if (s.isEmpty) return '';
    return '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_esc(s)}</t></is></c>';
  }

  static String _sheetXml(XlsxSheet sheet) {
    final cols = sheet.headers.length;
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
      ..write('<sheetViews><sheetView workbookViewId="0">'
          '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
          '</sheetView></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="15"/>');

    if (cols > 0) {
      b.write('<cols>');
      for (var c = 0; c < cols; c++) {
        final w = (sheet.widths != null && c < sheet.widths!.length)
            ? sheet.widths![c]
            : _guessWidth(sheet, c);
        b.write('<col min="${c + 1}" max="${c + 1}" width="$w" customWidth="1"/>');
      }
      b.write('</cols>');
    }

    b.write('<sheetData>');
    b.write('<row r="1">');
    for (var c = 0; c < cols; c++) {
      b.write(_cell('${colName(c)}1', sheet.headers[c], header: true));
    }
    b.write('</row>');
    for (var r = 0; r < sheet.rows.length; r++) {
      final rowNum = r + 2;
      b.write('<row r="$rowNum">');
      final row = sheet.rows[r];
      for (var c = 0; c < row.length && c < cols; c++) {
        b.write(_cell('${colName(c)}$rowNum', row[c]));
      }
      b.write('</row>');
    }
    b.write('</sheetData>');

    if (cols > 0) {
      final last = sheet.rows.length + 1;
      b.write('<autoFilter ref="A1:${colName(cols - 1)}$last"/>');
    }
    b.write('<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>');
    b.write('</worksheet>');
    return b.toString();
  }

  static double _guessWidth(XlsxSheet sheet, int c) {
    var len = sheet.headers[c].length;
    for (final row in sheet.rows.take(200)) {
      if (c >= row.length) continue;
      final v = row[c];
      final l = v is DateTime ? 11 : (v?.toString().length ?? 0);
      if (l > len) len = l;
    }
    final w = len + 3.0;
    return w < 8 ? 8 : (w > 50 ? 50 : w);
  }

  static String _contentTypes(int sheetCount) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write('<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>')
      ..write('<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>')
      ..write('<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>')
      ..write('<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>');
    for (var i = 1; i <= sheetCount; i++) {
      b.write('<Override PartName="/xl/worksheets/sheet$i.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    }
    b.write('</Types>');
    return b.toString();
  }

  static const String _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
      '</Relationships>';

  static const String _appXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
      '<Application>GymGenius</Application></Properties>';

  static String _coreXml() {
    final now = DateTime.now().toUtc();
    final iso = '${now.toIso8601String().split('.').first}Z';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>GymGenius export</dc:title><dc:creator>GymGenius</dc:creator>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$iso</dcterms:created>'
        '</cp:coreProperties>';
  }

  static String _workbook(List<String> names) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
      ..write('<bookViews><workbookView/></bookViews><sheets>');
    for (var i = 0; i < names.length; i++) {
      b.write('<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
    }
    b.write('</sheets></workbook>');
    return b.toString();
  }

  static String _workbookRels(int sheetCount) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (var i = 1; i <= sheetCount; i++) {
      b.write('<Relationship Id="rId$i" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
          'Target="worksheets/sheet$i.xml"/>');
    }
    b.write('<Relationship Id="rId${sheetCount + 1}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
        'Target="styles.xml"/>');
    b.write('</Relationships>');
    return b.toString();
  }

  static const String _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="2">'
      '<numFmt numFmtId="164" formatCode="yyyy-mm-dd hh:mm"/>'
      '<numFmt numFmtId="165" formatCode="0.0#"/>'
      '</numFmts>'
      '<fonts count="2">'
      '<font><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font>'
      '</fonts>'
      '<fills count="3">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF18181B"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="4">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';
}
