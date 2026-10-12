import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// One big number with a label (the top row of the Overview screen).
class Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const Kpi(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
