import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/gazette_record.dart';
import '../theme/app_theme.dart';

class ResultCard extends StatelessWidget {
  final GazetteRecord record;
  const ResultCard({super.key, required this.record});

  Color get _pillColor {
    switch (record.status) {
      case ResultStatus.pass:
        return AppColors.pass;
      case ResultStatus.fail:
        return AppColors.fail;
      case ResultStatus.absent:
        return AppColors.absent;
      case ResultStatus.withheld:
        return AppColors.withheld;
      case ResultStatus.cancelled:
        return AppColors.cancelled;
      default:
        return AppColors.textMuted;
    }
  }

  Color get _gradeColor {
    switch (record.grade) {
      case 'A+':
        return AppColors.gradeAPlus;
      case 'A':
        return AppColors.gradeA;
      case 'B':
        return AppColors.gradeB;
      case 'C':
        return AppColors.gradeC;
      case 'D':
        return AppColors.gradeD;
      case 'E':
        return AppColors.gradeE;
      default:
        return AppColors.textMuted;
    }
  }

  String _fullDob(String? dob) {
    if (dob == null) return '—';
    final p = dob.split('/');
    if (p.length != 3) return dob;
    var yy = int.tryParse(p[2]);
    if (yy == null) return dob;
    if (p[2].length <= 2) {
      final full = yy < 50 ? 2000 + yy : 1900 + yy;
      return '${p[0]}/${p[1]}/$full';
    }
    return dob;
  }

  @override
  Widget build(BuildContext context) {
    final monospace = GoogleFonts.jetBrainsMono();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${record.rollNumber}',
                style: monospace.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'DOB ${_fullDob(record.dob)}',
                    style: monospace.copyWith(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (record.status != ResultStatus.pass && record.remark.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      record.remark,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (record.status == ResultStatus.pass && record.grade != null)
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: _gradeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      record.grade!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _pillColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.status.label,
                    style: TextStyle(
                      color: _pillColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (record.status == ResultStatus.pass && record.marks != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${record.marks} marks',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
