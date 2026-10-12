import 'package:flutter/material.dart';

/// Draws the little response-time line chart on each service card.
/// A CustomPainter lets us draw shapes by hand on a canvas.
class SparkPainter extends CustomPainter {
  final List<double> data; // the last 30 readings
  final Color color;

  SparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    // Find the biggest value so the chart scales to fit. Minimum 100 so that
    // normal noise does not look like a huge spike.
    var maxV = 100.0;
    for (final v in data) {
      if (v > maxV) maxV = v;
    }

    // Turn each reading into an (x, y) point and join them with a line.
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height - (data[i] / maxV) * (size.height - 6) - 3;
      if (i == 0) {
        path.moveTo(x, y); // start of the line
      } else {
        path.lineTo(x, y); // continue the line
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant SparkPainter oldDelegate) => true;
}
