import 'package:flutter/material.dart';

/// Lays children out in columns, and changes the column count by screen width:
/// wide screen = [maxCols] columns, medium = 2, phone = 1.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int maxCols;

  const ResponsiveGrid({super.key, required this.children, this.maxCols = 3});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder tells us how much width we have to work with.
    return LayoutBuilder(builder: (context, c) {
      const spacing = 16.0;
      final cols = c.maxWidth >= 900 ? maxCols : (c.maxWidth >= 560 ? 2 : 1);
      final w = (c.maxWidth - spacing * (cols - 1)) / cols; // width of one cell
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children.map((e) => SizedBox(width: w, child: e)).toList(),
      );
    });
  }
}
