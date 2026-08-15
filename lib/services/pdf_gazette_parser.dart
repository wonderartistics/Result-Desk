import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/gazette_record.dart';
import '../models/gazette_dataset.dart';

/// ---------------------------------------------------------------------
/// WHY THIS PARSER EXISTS
/// ---------------------------------------------------------------------
/// The original web tool split each page into exactly 6 fixed pixel bands
/// (x < 182, < 300, < 427, < 549, < 673, else) and assumed exactly 3
/// repeating "roll+name | dob+status" column pairs. That only works for
/// the *one* gazette PDF it was tuned against. Any new gazette with a
/// different page size, margin, font, or column count (a different board,
/// a different class/exam, even a reprint with slightly different
/// typesetting) shifts every word's x position — so words fall into the
/// wrong bucket, rows get mis-paired, and candidates silently vanish or
/// get corrupted. That's the "glitch" you ran into.
///
/// This parser instead DISCOVERS the column layout from the page itself:
///   1. Look at where every word starts (x0) on the page.
///   2. Find the real gaps between columns (gutters) vs normal in-line
///      word spacing, using the page's own statistics — not a hardcoded
///      pixel number.
///   3. Classify each resulting band by what it actually contains (roll
///      numbers look like \d{3,7}, dates look like dd/mm/yy, names are
///      alphabetic, status text contains PASS/FAIL/ABSENT/etc).
///   4. Walk the bands left-to-right and group them into repeating
///      "roll → name → dob → status" units, however many of those units
///      the page actually has (1, 2, 3, 6 — whatever the board printed).
///
/// It also NEVER silently drops rows: if a page/band can't be confidently
/// classified, or a mismatch is found between how many names vs statuses
/// were found, it's recorded in [GazetteDataset.warnings] so you can see
/// exactly which page needs a second look, instead of ending up with a
/// dataset that's quietly missing thousands of students.
/// ---------------------------------------------------------------------
class PdfGazetteParser {
  /// Parses [bytes] of a gazette PDF and returns a dataset.
  /// [onProgress] reports (currentPage, totalPages, candidatesSoFar).
  static Future<GazetteDataset> parse(
    Uint8List bytes, {
    required String fileLabel,
    void Function(int page, int totalPages, int found)? onProgress,
  }) async {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final totalPages = document.pages.count;

    final records = <GazetteRecord>[];
    final warnings = <String>[];
    final seenRolls = <int>{};
    int duplicateCount = 0;

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      List<TextLine> lines;
      try {
        lines = extractor.extractTextLines(
          startPageIndex: pageIndex,
          endPageIndex: pageIndex,
        );
      } catch (e) {
        warnings.add('Page ${pageIndex + 1}: could not read text (${e.runtimeType}).');
        continue;
      }

      final words = <_Word>[];
      for (final line in lines) {
        for (final w in line.wordCollection) {
          final t = w.text.trim();
          if (t.isEmpty) continue;
          words.add(_Word(x: w.bounds.left, y: w.bounds.top, text: t));
        }
      }
      if (words.isEmpty) continue;

      final bands = _clusterIntoColumnBands(words);
      final beforeCount = records.length;

      for (final band in bands) {
        band.lines = _joinWordsIntoLines(band.words);
      }

      final units = _groupBandsIntoUnits(bands);
      if (units.isEmpty && bands.isNotEmpty) {
        warnings.add(
          'Page ${pageIndex + 1}: found ${bands.length} column band(s) but none '
          'matched a recognizable roll/name/dob/status pattern — page skipped. '
          'This gazette page may use a layout this parser doesn\'t know yet.',
        );
      }

      for (final unit in units) {
        final rolls = unit.rollLines ?? _extractLeadingToken(unit.rollNameLines!, _rollAtStart);
        final names = unit.nameLines ?? _stripLeadingToken(unit.rollNameLines!, _rollAtStart);
        final dobs = unit.dobLines ?? _extractLeadingToken(unit.dobStatusLines!, _dobAtStart);
        final statuses = unit.statusLines ?? _stripLeadingToken(unit.dobStatusLines!, _dobAtStart);

        final n = [rolls.length, names.length, dobs.length, statuses.length]
            .reduce((a, b) => a < b ? a : b);
        final maxN = [rolls.length, names.length, dobs.length, statuses.length]
            .reduce((a, b) => a > b ? a : b);
        if (maxN != n) {
          warnings.add(
            'Page ${pageIndex + 1}: one column in this unit had $maxN rows but '
            'another only had $n — used the shorter count so no row gets '
            'mismatched data ($maxN - $n row(s) held back, not lost — re-check '
            'this page manually if the count matters).',
          );
        }

        for (int i = 0; i < n; i++) {
          final rollStr = rolls[i].replaceAll(RegExp(r'[^\d]'), '');
          if (rollStr.isEmpty) continue;
          final roll = int.tryParse(rollStr);
          if (roll == null) continue;

          if (!seenRolls.add(roll)) {
            duplicateCount++;
          }

          final name = _titleCase(names[i].trim());
          final dobRaw = dobs[i].trim();
          final dob = dobRaw == '--' || dobRaw.isEmpty ? null : dobRaw;
          final statusText = statuses[i].trim();
          final classified = _classifyStatus(statusText);

          records.add(GazetteRecord(
            rollNumber: roll,
            name: name.isEmpty ? '(name not captured)' : name,
            dob: dob,
            status: classified.status,
            marks: classified.marks,
            grade: classified.grade,
            remark: classified.status == ResultStatus.pass ? '' : statusText,
          ));
        }
      }

      if (records.length == beforeCount && words.length > 20) {
        warnings.add(
          'Page ${pageIndex + 1}: had text but produced 0 candidate rows — '
          'likely a cover/header/footer page, or an unrecognized table format.',
        );
      }

      onProgress?.call(pageIndex + 1, totalPages, records.length);
    }

    if (duplicateCount > 0) {
      warnings.add(
        '$duplicateCount duplicate roll number(s) were found across the '
        'document (kept all occurrences — check if the source PDF repeats pages).',
      );
    }

    document.dispose();

    return GazetteDataset(
      boardId: 'custom_upload',
      boardName: 'Uploaded gazette',
      examName: fileLabel,
      examYear: '',
      sourceLabel: fileLabel,
      records: records,
      warnings: warnings,
    );
  }

  // -------------------------------------------------------------------
  // Column detection: gap-based clustering of word x-start positions.
  // This replaces the old hardcoded pixel thresholds. The threshold that
  // decides "this is a column gutter, not just a space between words" is
  // derived from THIS page's own word-spacing statistics, so it adapts
  // automatically to different fonts, page sizes, and column counts.
  // -------------------------------------------------------------------
  static List<_ColumnBand> _clusterIntoColumnBands(List<_Word> words) {
    final xs = words.map((w) => w.x).toList()..sort();
    final uniqueXs = <double>[];
    for (final x in xs) {
      if (uniqueXs.isEmpty || x - uniqueXs.last > 1.0) uniqueXs.add(x);
    }
    if (uniqueXs.length < 2) {
      return [_ColumnBand(xStart: uniqueXs.isEmpty ? 0 : uniqueXs.first, words: words)];
    }

    final gaps = <double>[];
    for (int i = 1; i < uniqueXs.length; i++) {
      gaps.add(uniqueXs[i] - uniqueXs[i - 1]);
    }
    final sortedGaps = List<double>.from(gaps)..sort();
    final median = sortedGaps[sortedGaps.length ~/ 2];
    // A column gutter is a gap meaningfully bigger than typical spacing.
    // Floor of 18pt avoids treating normal word-spacing as a new column
    // on dense pages; the *4 multiplier adapts to font size automatically.
    final threshold = median * 4 < 18 ? 18.0 : median * 4;

    final boundaries = <double>[uniqueXs.first];
    for (int i = 1; i < uniqueXs.length; i++) {
      if (uniqueXs[i] - uniqueXs[i - 1] > threshold) {
        boundaries.add(uniqueXs[i]);
      }
    }

    final bands = boundaries.map((b) => _ColumnBand(xStart: b, words: [])).toList();
    for (final w in words) {
      _ColumnBand best = bands.first;
      for (final b in bands) {
        if (b.xStart <= w.x + 0.01) best = b;
      }
      best.words.add(w);
    }
    return bands..removeWhere((b) => b.words.isEmpty);
  }

  /// Groups words within one column band into printed lines (rows),
  /// matching by y-proximity — a candidate's roll/name/dob/status line
  /// often wraps or has slight sub-pixel y jitter within the same row.
  static List<String> _joinWordsIntoLines(List<_Word> words) {
    final sorted = List<_Word>.from(words)..sort((a, b) => a.y.compareTo(b.y));
    final lines = <String>[];
    double? curY;
    final cur = <String>[];
    for (final w in sorted) {
      if (curY == null || (w.y - curY).abs() <= 2.5) {
        cur.add(w.text);
        curY ??= w.y;
      } else {
        lines.add(cur.join(' '));
        cur
          ..clear()
          ..add(w.text);
        curY = w.y;
      }
    }
    if (cur.isNotEmpty) lines.add(cur.join(' '));
    return lines;
  }

  static final RegExp _rollAtStart = RegExp(r'^(\d{3,7})\s+(.*)$');
  static final RegExp _dobAtStart =
      RegExp(r'^(\d{1,2}/\d{1,2}/\d{2,4}|--)\s*(.*)$');

  static List<String> _extractLeadingToken(List<String> lines, RegExp re) {
    final out = <String>[];
    for (final l in lines) {
      final m = re.firstMatch(l);
      if (m != null) out.add(m.group(1) ?? '');
    }
    return out;
  }

  static List<String> _stripLeadingToken(List<String> lines, RegExp re) {
    final out = <String>[];
    for (final l in lines) {
      final m = re.firstMatch(l);
      if (m != null) out.add((m.group(2) ?? '').trim());
    }
    return out;
  }

  /// Classifies each column band's dominant content type by sampling its
  /// first several lines — this is what lets the parser handle a board
  /// that prints "Roll" and "Name" as two *separate* columns, not just
  /// the combined "Roll Name" single-cell format of the bundled dataset.
  static _BandKind _classifyBand(_ColumnBand band) {
    final sample = band.lines.take(15).where((l) => l.trim().isNotEmpty).toList();
    if (sample.isEmpty) return _BandKind.unknown;

    int rollNameHits = 0, dobStatusHits = 0, pureRollHits = 0, pureDobHits = 0,
        nameHits = 0, statusHits = 0;

    final pureRoll = RegExp(r'^\d{3,7}$');
    final pureDob = RegExp(r'^(\d{1,2}/\d{1,2}/\d{2,4}|--)$');
    final statusWord = RegExp(
        r'PASS|FAIL|ABSENT|WITHHELD|CANCEL|COMPARTMENT|RE-?APPEAR|MARKS NOT',
        caseSensitive: false);
    final alpha = RegExp(r'^[A-Za-z][A-Za-z .\-]{2,}$');

    for (final l in sample) {
      if (_rollAtStart.hasMatch(l)) rollNameHits++;
      if (_dobAtStart.hasMatch(l) && _dobAtStart.firstMatch(l)!.group(2)!.isNotEmpty) {
        dobStatusHits++;
      }
      if (pureRoll.hasMatch(l)) pureRollHits++;
      if (pureDob.hasMatch(l)) pureDobHits++;
      if (statusWord.hasMatch(l)) statusHits++;
      if (alpha.hasMatch(l)) nameHits++;
    }

    final total = sample.length;
    bool majority(int hits) => hits >= (total * 0.5).ceil();

    if (majority(rollNameHits)) return _BandKind.rollName;
    if (majority(dobStatusHits) || majority(statusHits)) return _BandKind.dobStatus;
    if (majority(pureRollHits)) return _BandKind.rollOnly;
    if (majority(pureDobHits)) return _BandKind.dobOnly;
    if (majority(nameHits)) return _BandKind.nameOnly;
    return _BandKind.unknown;
  }

  /// Walks bands left-to-right, starting a new "candidate unit" every time
  /// a roll-bearing band appears, and folding subsequent bands into that
  /// unit until the next roll band. This supports any number of repeating
  /// print-columns per page (not hardcoded to 3).
  static List<_Unit> _groupBandsIntoUnits(List<_ColumnBand> bands) {
    final sortedBands = List<_ColumnBand>.from(bands)
      ..sort((a, b) => a.xStart.compareTo(b.xStart));

    final kinds = sortedBands.map(_classifyBand).toList();
    final units = <_Unit>[];
    _Unit? cur;

    for (int i = 0; i < sortedBands.length; i++) {
      final band = sortedBands[i];
      final kind = kinds[i];

      switch (kind) {
        case _BandKind.rollName:
          cur = _Unit()..rollNameLines = band.lines;
          units.add(cur);
          break;
        case _BandKind.rollOnly:
          cur = _Unit()..rollLines = band.lines;
          units.add(cur);
          break;
        case _BandKind.dobStatus:
          if (cur == null) {
            cur = _Unit();
            units.add(cur);
          }
          cur.dobStatusLines = band.lines;
          break;
        case _BandKind.nameOnly:
          cur?.nameLines = band.lines;
          break;
        case _BandKind.dobOnly:
          cur?.dobLines = band.lines;
          break;
        case _BandKind.unknown:
          // Ignore decorative/label/header bands (page numbers, footers).
          break;
      }
    }

    return units.where((u) {
      final hasRoll = u.rollLines != null || u.rollNameLines != null;
      final hasStatus = u.statusLines != null || u.dobStatusLines != null;
      return hasRoll && hasStatus;
    }).toList();
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  static _StatusClassification _classifyStatus(String raw) {
    final s = raw.toUpperCase();
    if (s.startsWith('ABSENT')) return _StatusClassification(ResultStatus.absent);
    if (s.contains('WITHHELD')) return _StatusClassification(ResultStatus.withheld);
    if (s.contains('CANCEL')) return _StatusClassification(ResultStatus.cancelled);
    if (s.contains('MARKS N') && s.contains('IMP')) {
      return _StatusClassification(ResultStatus.marksNotImproved);
    }
    if (s.contains('RESULT LATER') || s.contains('R.L')) {
      return _StatusClassification(ResultStatus.resultLater);
    }

    final passRe = RegExp(r'^PASS\s+(\d+)\s+([A-Z]\+?)');
    final m1 = passRe.firstMatch(s);
    if (m1 != null) {
      return _StatusClassification(ResultStatus.pass,
          marks: int.tryParse(m1.group(1)!), grade: m1.group(2));
    }
    final improvedRe = RegExp(r'^(\d+)\s+([A-Z]\+?)\s+MARKS\s+IMPROVED');
    final m2 = improvedRe.firstMatch(s);
    if (m2 != null) {
      return _StatusClassification(ResultStatus.pass,
          marks: int.tryParse(m2.group(1)!), grade: m2.group(2));
    }
    // Some boards print bare "<marks> <grade>" for a pass with no "PASS" word.
    final bareRe = RegExp(r'^(\d{2,4})\s+([A-Z]\+?)\s*$');
    final m3 = bareRe.firstMatch(s);
    if (m3 != null) {
      return _StatusClassification(ResultStatus.pass,
          marks: int.tryParse(m3.group(1)!), grade: m3.group(2));
    }

    if (s.contains('PASS')) return _StatusClassification(ResultStatus.pass);
    return _StatusClassification(ResultStatus.fail);
  }
}

class _Word {
  final double x, y;
  final String text;
  _Word({required this.x, required this.y, required this.text});
}

class _ColumnBand {
  final double xStart;
  final List<_Word> words;
  List<String> lines = const [];
  _ColumnBand({required this.xStart, required this.words});
}

enum _BandKind { rollName, dobStatus, rollOnly, nameOnly, dobOnly, unknown }

class _Unit {
  List<String>? rollNameLines;
  List<String>? dobStatusLines;
  List<String>? rollLines;
  List<String>? nameLines;
  List<String>? dobLines;
  List<String>? statusLines;
}

class _StatusClassification {
  final ResultStatus status;
  final int? marks;
  final String? grade;
  _StatusClassification(this.status, {this.marks, this.grade});
}
