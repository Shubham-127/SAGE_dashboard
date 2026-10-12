import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../widgets/panel.dart';
import '../widgets/pill.dart';

/// One row on the progress board.
class Stage {
  final String name;
  final String analogy; // the real-life picture (pizza shops and detectives)
  final String what; // what it does, in plain words
  final String status; // Built / In progress / Prototype / Planned
  const Stage(this.name, this.analogy, this.what, this.status);
}

/// An honest status board: what is built, what is planned, and what is
/// simulated in this prototype. Update the "status" values as you build.
class ArchitecturePage extends StatelessWidget {
  ArchitecturePage({super.key});

  static const stages = [
    Stage('Demo microservices', 'The shops',
        'Order, Inventory and Payment (Spring Boot) with built-in fault injection.', 'Built'),
    Stage('Kafka event pipeline', 'The wire to the control room',
        'Each request timing is published to sage.metrics. Inventory publishes today; Order and Payment are next.',
        'In progress'),
    Stage('Redis anomaly detection', 'The notepad of normal',
        'Keeps a rolling baseline per service and flags sudden jumps (z-score).', 'Planned'),
    Stage('Incident correlation', 'Which shop is the real cause?',
        'Groups linked anomalies into one incident using the service dependency map.', 'Planned'),
    Stage('pgvector knowledge base', "The detective's old case files",
        'Searches past incidents by meaning and only trusts matches of 0.75 or higher.', 'Planned'),
    Stage('Spring AI diagnosis', 'The AI detective',
        'Sends live evidence plus any matched case to an LLM and gets a root cause, confidence and action.',
        'Planned'),
    Stage('Safety gate', 'Rules for the robot',
        'Auto-runs only whitelisted, high-confidence fixes. Everything else goes to a human.', 'Planned'),
    Stage('Kubernetes operator', 'The robot',
        'Carries out approved fixes: restart, scale or roll back.', 'Planned'),
    Stage('Keycloak authentication', 'The badge check',
        'Viewer and Admin roles. This prototype uses a mock login.', 'Planned'),
    Stage('Flutter dashboard', 'The control-room screen',
        'This app. It runs on simulated data so the full idea can be shown before the backend is finished.',
        'Prototype'),
  ];

  Color _color(String s) => switch (s) {
        'Built' => AppColors.good,
        'In progress' => AppColors.warn,
        'Prototype' => AppColors.accent,
        _ => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Panel(
        title: 'How SAGE works, stage by stage',
        child: Column(children: [
          for (final s in stages)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.panel2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text(s.analogy,
                        style: const TextStyle(
                            color: AppColors.accent, fontSize: 12.5, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 6),
                    Text(s.what,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
                  ]),
                ),
                const SizedBox(width: 12),
                Pill(s.status, _color(s.status)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      const Panel(
        title: 'What is real and what is simulated here',
        child: Text(
          'Real: the three Spring Boot microservices and the cascade failure between them. '
          'Simulated in this prototype: the metric stream, anomaly detection, similarity search, AI diagnosis, '
          'safety gate and Kubernetes actions. The rules they follow (0.75 similarity threshold, 85% confidence '
          'gate, whitelisted actions only) are the same ones the real backend will use.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
      ),
    ]);
  }
}
