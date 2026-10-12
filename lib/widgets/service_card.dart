import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/enums.dart';
import '../models/service_info.dart';
import '../state/sage_state.dart';
import 'pill.dart';
import 'spark_painter.dart';

/// One tile per microservice: name, status pill, numbers and a little chart.
/// If the service is fine but a neighbour it calls is broken, the tile says so.
class ServiceCard extends StatelessWidget {
  final ServiceInfo s;
  ServiceCard(this.s, {super.key});

  /// A small "label over value" block, e.g. Avg latency / 45 ms.
  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          Text(value,
              style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final h = sage.health(s.name);
    final color = switch (h) {
      Health.healthy => AppColors.good,
      Health.degraded => AppColors.warn,
      Health.down => AppColors.bad,
    };
    final label = switch (h) {
      Health.healthy => 'Healthy',
      Health.degraded => 'Degraded',
      Health.down => 'Down',
    };
    final src = sage.cascadeSource(s.name); // the broken neighbour, if any

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: h == Health.healthy ? AppColors.border : color.withOpacity(0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
              Text('port ${s.port}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
          Pill(label, color),
        ]),
        const SizedBox(height: 10),
        if (src != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Looks broken only because it depends on $src',
                style: const TextStyle(color: AppColors.warn, fontSize: 12)),
          ),
        Row(children: [
          _metric('Avg latency', '${sage.avgLatency(s.name).round()} ms'),
          const SizedBox(width: 28),
          _metric('Error rate', '${sage.errorRate[s.name]!.toStringAsFixed(1)}%'),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: CustomPaint(painter: SparkPainter(List.of(s.latency), color)),
        ),
      ]),
    );
  }
}
