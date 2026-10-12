import 'package:flutter/material.dart';

/// A small coloured label such as "Healthy" or "Confidence 92%".
/// Pass the text, the colour and (optionally) an icon.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const Pill(this.text, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14), // very light version of the colour
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 5)],
        Flexible(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
