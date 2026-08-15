/// A single candidate's row from a result gazette.
///
/// This shape is intentionally board-agnostic: every board publishes some
/// variant of {roll number, name, date of birth, result status, marks,
/// grade, remarks}. Board-specific quirks (status wording, column order,
/// how "compartment/fail" is written, etc.) are normalized into this model
/// by the parser layer — the UI never has to know which board a record
/// came from.
enum ResultStatus { pass, fail, absent, withheld, cancelled, resultLater, marksNotImproved, other }

extension ResultStatusX on ResultStatus {
  String get label {
    switch (this) {
      case ResultStatus.pass:
        return 'Pass';
      case ResultStatus.fail:
        return 'Fail / Compartment';
      case ResultStatus.absent:
        return 'Absent';
      case ResultStatus.withheld:
        return 'Withheld';
      case ResultStatus.cancelled:
        return 'Cancelled';
      case ResultStatus.resultLater:
        return 'Result later';
      case ResultStatus.marksNotImproved:
        return 'Marks not improved';
      case ResultStatus.other:
        return 'Other';
    }
  }

  /// Single-letter code, kept compatible with the legacy web dataset
  /// (P/F/A/W/C/R/N/O) so the bundled JSON can be read without migration.
  String get code {
    switch (this) {
      case ResultStatus.pass:
        return 'P';
      case ResultStatus.fail:
        return 'F';
      case ResultStatus.absent:
        return 'A';
      case ResultStatus.withheld:
        return 'W';
      case ResultStatus.cancelled:
        return 'C';
      case ResultStatus.resultLater:
        return 'R';
      case ResultStatus.marksNotImproved:
        return 'N';
      case ResultStatus.other:
        return 'O';
    }
  }

  static ResultStatus fromCode(String? code) {
    switch (code) {
      case 'P':
        return ResultStatus.pass;
      case 'F':
        return ResultStatus.fail;
      case 'A':
        return ResultStatus.absent;
      case 'W':
        return ResultStatus.withheld;
      case 'C':
        return ResultStatus.cancelled;
      case 'R':
        return ResultStatus.resultLater;
      case 'N':
        return ResultStatus.marksNotImproved;
      default:
        return ResultStatus.other;
    }
  }
}

class GazetteRecord {
  final int rollNumber;
  final String name;

  /// Stored as-is in DD/MM/YY (or DD/MM/YYYY) form, or null if the gazette
  /// doesn't publish DOB for this candidate/board.
  final String? dob;

  final ResultStatus status;
  final int? marks;
  final String? grade;

  /// Free-text remark: subject-wise fail detail, "MAY REAPPEAR..." notice,
  /// or whatever the board's own wording is. Shown verbatim for
  /// transparency instead of being force-fit into a fixed schema.
  final String remark;

  const GazetteRecord({
    required this.rollNumber,
    required this.name,
    required this.status,
    this.dob,
    this.marks,
    this.grade,
    this.remark = '',
  });

  /// Legacy compact array form: [roll, name, dob, statusCode, marks, grade, remark]
  /// Matches the original web app's embedded dataset shape exactly, so the
  /// bundled 285,987-row JSON can be loaded with zero transformation cost.
  factory GazetteRecord.fromLegacyArray(List<dynamic> a) {
    return GazetteRecord(
      rollNumber: a[0] is int ? a[0] as int : int.parse(a[0].toString()),
      name: (a[1] as String?)?.trim() ?? '',
      dob: (a[2] as String?) == '--' ? null : a[2] as String?,
      status: ResultStatusX.fromCode(a[3] as String?),
      marks: a.length > 4 ? a[4] as int? : null,
      grade: a.length > 5 ? a[5] as String? : null,
      remark: a.length > 6 ? (a[6] as String?) ?? '' : '',
    );
  }

  List<dynamic> toLegacyArray() => [
        rollNumber,
        name,
        dob ?? '--',
        status.code,
        marks,
        grade,
        remark,
      ];
}
