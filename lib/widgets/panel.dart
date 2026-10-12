import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// A rounded box with an optional title. Used on almost every screen.
/// Real-life picture: a labelled tray that holds other things.
class Panel extends StatelessWidget {
  final String? title; // heading shown at the top (optional)
  final Widget? trailing; // small widget on the right of the heading (optional)
  final Widget child; // whatever goes inside the box

  const Panel({super.key, this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(children: [
              Expanded(
                child: Text(title!,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
              ),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}
