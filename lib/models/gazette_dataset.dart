import 'gazette_record.dart';

/// One loaded gazette (bundled default, or a PDF the user parsed) plus the
/// metadata needed to label it in the UI and, later, to pick the right
/// board-specific parsing hints if boards diverge in format.
class GazetteDataset {
  final String boardId;
  final String boardName;
  final String examName;
  final String examYear;
  final String sourceLabel;
  final List<GazetteRecord> records;

  /// Pages the parser found unparseable / rows it had to skip, surfaced to
  /// the user instead of being silently dropped (this is the #1 fix over
  /// the old web version, which would quietly lose candidates on gazettes
  /// with a slightly different layout).
  final List<String> warnings;

  const GazetteDataset({
    required this.boardId,
    required this.boardName,
    required this.examName,
    required this.examYear,
    required this.sourceLabel,
    required this.records,
    this.warnings = const [],
  });

  int get total => records.length;
  int get passCount => records.where((r) => r.status == ResultStatus.pass).length;
  int get absentCount => records.where((r) => r.status == ResultStatus.absent).length;
  double get passPercent => total == 0 ? 0 : (passCount / total) * 100;

  GazetteDataset copyWith({
    String? boardId,
    String? boardName,
    String? examName,
    String? examYear,
    String? sourceLabel,
    List<GazetteRecord>? records,
    List<String>? warnings,
  }) {
    return GazetteDataset(
      boardId: boardId ?? this.boardId,
      boardName: boardName ?? this.boardName,
      examName: examName ?? this.examName,
      examYear: examYear ?? this.examYear,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      records: records ?? this.records,
      warnings: warnings ?? this.warnings,
    );
  }
}
