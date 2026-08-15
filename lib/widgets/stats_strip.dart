import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/gazette_dataset.dart';

class StatsStrip extends StatelessWidget {
  final GazetteDataset dataset;
  const StatsStrip({super.key, required this.dataset});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('Candidates', dataset.total.toString()),
      _StatItem('Passed', dataset.passCount.toString()),
      _StatItem('Pass %', '${dataset.passPercent.toStringAsFixed(1)}%'),
      _StatItem('Absent', dataset.absentCount.toString()),
    ];
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 1),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
                borderRadius: BorderRadius.circular(i == 0
                    ? 10
                    : i == items.length - 1
                        ? 10
                        : 0),
              ),
              child: Column(
                children: [
                  Text(
                    items[i].value,
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 9.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatItem {
  final String label, value;
  _StatItem(this.label, this.value);
}
