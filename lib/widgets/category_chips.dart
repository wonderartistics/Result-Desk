import 'package:flutter/material.dart';
import '../models/gazette_record.dart';
import '../theme/app_theme.dart';

class CategoryChips extends StatelessWidget {
  final ResultStatus? selected;
  final ValueChanged<ResultStatus?> onSelect;
  const CategoryChips({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = <ResultStatus?>[
      null,
      ResultStatus.pass,
      ResultStatus.fail,
      ResultStatus.absent,
      ResultStatus.withheld,
      ResultStatus.cancelled,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          final label = opt == null ? 'All results' : opt.label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onSelect(opt),
              selectedColor: AppColors.navy,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.navy : Colors.black.withOpacity(0.12),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
