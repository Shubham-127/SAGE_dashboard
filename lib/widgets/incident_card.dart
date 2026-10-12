import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/formatters.dart';
import '../models/enums.dart';
import '../models/incident.dart';
import '../state/sage_state.dart';
import 'pill.dart';

/// Colour and wording for each incident status.
Color statusColor(IncidentStatus s) => switch (s) {
      IncidentStatus.awaitingApproval => AppColors.warn,
      IncidentStatus.executing => AppColors.accent,
      IncidentStatus.autoHealed => AppColors.good,
      IncidentStatus.resolved => AppColors.good,
      IncidentStatus.dismissed => AppColors.muted,
    };

String statusLabel(IncidentStatus s) => switch (s) {
      IncidentStatus.awaitingApproval => 'Needs a human',
      IncidentStatus.executing => 'Fix running',
      IncidentStatus.autoHealed => 'Auto-healed',
      IncidentStatus.resolved => 'Resolved by admin',
      IncidentStatus.dismissed => 'Dismissed',
    };

/// A vertical list of incident cards (or a friendly message if there are none).
class IncidentList extends StatelessWidget {
  final List<Incident> items;
  final String emptyText;
  IncidentList({super.key, required this.items, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(emptyText, style: const TextStyle(color: AppColors.muted));
    }
    return Column(children: [
      for (final i in items)
        // ValueKey(i.id) lets Flutter keep each card's "expanded" state when the list redraws.
        Padding(padding: const EdgeInsets.only(bottom: 12), child: IncidentCard(i, key: ValueKey(i.id))),
    ]);
  }
}

/// One incident: what broke, why (the AI explanation), how sure SAGE is,
/// what the safety gate decided, and the buttons a human can press.
class IncidentCard extends StatelessWidget {
  final Incident inc;
  IncidentCard(this.inc, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(inc.status);
    final isAdmin = sage.role == Role.admin;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // --- title row ---
        Row(children: [
          Expanded(
            child: Text('${inc.id}  ${inc.fault.title} on ${inc.rootService}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
          const SizedBox(width: 8),
          Pill(statusLabel(inc.status), color),
        ]),
        const SizedBox(height: 4),
        Text('Detected at ${fmtTime(inc.time)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 10),

        // --- the AI explanation ---
        Text(inc.rootCause, style: const TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 10),

        // --- small facts as pills ---
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill('Confidence ${(inc.confidence * 100).round()}%',
              inc.confidence >= SageState.confidenceGate ? AppColors.good : AppColors.warn,
              icon: Icons.insights),
          inc.precedent != null
              ? Pill('Precedent found (similarity ${inc.similarity.toStringAsFixed(2)})', AppColors.good,
                  icon: Icons.history)
              : Pill('No precedent (best ${inc.similarity.toStringAsFixed(2)})', AppColors.warn,
                  icon: Icons.help_outline),
          Pill('Action: ${inc.action}', AppColors.accent, icon: Icons.build_outlined),
          Pill(inc.autoDecision ? 'Gate: AUTO_EXECUTE' : 'Gate: ESCALATE_TO_HUMAN',
              inc.autoDecision ? AppColors.good : AppColors.warn,
              icon: Icons.shield_outlined),
        ]),

        if (inc.affected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Also showing symptoms: ${inc.affected.join(", ")} (not the root cause)',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),

        // --- expandable evidence ---
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: const Text('Evidence and reasoning',
                style: TextStyle(fontSize: 13.5, color: AppColors.text)),
            children: [
              for (final e in inc.evidence)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('- $e',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
                  ),
                ),
            ],
          ),
        ),

        // --- buttons, only while a human decision is needed ---
        if (inc.status == IncidentStatus.awaitingApproval)
          Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton.icon(
              onPressed: isAdmin ? () => sage.approve(inc) : null, // null = disabled for viewers
              icon: const Icon(Icons.check),
              label: const Text('Approve fix'),
            ),
            OutlinedButton(
              onPressed: isAdmin ? () => sage.dismiss(inc) : null,
              child: const Text('Dismiss'),
            ),
            if (!isAdmin)
              const Text('Admin role required (viewers get 403)',
                  style: TextStyle(color: AppColors.warn, fontSize: 12.5)),
          ]),
      ]),
    );
  }
}
