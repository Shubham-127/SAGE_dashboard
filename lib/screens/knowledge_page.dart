import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/enums.dart';
import '../models/past_case.dart';
import '../state/sage_state.dart';
import '../widgets/panel.dart';
import '../widgets/pill.dart';

/// The "detective's case files": every past incident SAGE can compare new problems to.
/// Cases marked "Learned from INC-xxx" were added automatically after a fix
/// (this is the learning loop).
class KnowledgePage extends StatelessWidget {
  KnowledgePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Past incidents SAGE can learn from',
      trailing: Pill('${sage.knowledgeBase.length} cases', AppColors.accent),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'In the real system these live in PostgreSQL with pgvector and are searched by meaning. '
          'A match only counts when similarity is at least 0.75. Every resolved incident is saved here, '
          'so the same problem is recognised next time.',
          style: TextStyle(color: AppColors.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        for (final c in sage.knowledgeBase) _caseTile(c),
      ]),
    );
  }

  Widget _caseTile(PastCase c) {
    final learned = c.source.startsWith('Learned');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: learned ? AppColors.good.withOpacity(0.5) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 8),
        Text(c.rootCause, style: const TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill(c.service, AppColors.muted),
          Pill(c.fault.apiName, AppColors.muted),
          Pill('Fix: ${c.fix}', AppColors.accent, icon: Icons.build_outlined),
          Pill('Seen ${c.timesSeen}x', AppColors.muted),
          Pill(c.source, learned ? AppColors.good : AppColors.muted,
              icon: learned ? Icons.school_outlined : Icons.archive_outlined),
        ]),
      ]),
    );
  }
}
