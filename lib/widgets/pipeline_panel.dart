import 'package:flutter/material.dart' hide StepState;
import '../core/app_colors.dart';
import '../models/enums.dart';
import '../models/pipeline_step.dart';
import '../state/sage_state.dart';
import 'panel.dart';
import 'pill.dart';

/// The "what SAGE is doing right now" list: 8 steps that light up in order.
///   grey circle = waiting,  spinner = running,  green tick = done
class PipelinePanel extends StatelessWidget {
  PipelinePanel({super.key});

  Widget _row(PipelineStep s) {
    Widget leading;
    switch (s.state) {
      case StepState.pending:
        leading = const Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.muted);
        break;
      case StepState.running:
        leading = const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent));
        break;
      case StepState.done:
        leading = const Icon(Icons.check_circle, size: 18, color: AppColors.good);
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: leading),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: s.state == StepState.pending ? AppColors.muted : AppColors.text)),
            if (s.detail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(s.detail,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
              ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Live pipeline',
      trailing: sage.pipelineRunning ? const Pill('running', AppColors.accent, icon: Icons.sync) : null,
      child: sage.pipeline.isEmpty
          ? const Text('Nothing running. Inject a fault to see every SAGE stage light up in order.',
              style: TextStyle(color: AppColors.muted, height: 1.4))
          : Column(children: sage.pipeline.map(_row).toList()),
    );
  }
}
