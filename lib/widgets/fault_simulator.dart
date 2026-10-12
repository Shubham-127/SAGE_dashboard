import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/enums.dart';
import '../state/sage_state.dart';
import 'panel.dart';
import 'pill.dart';

/// "Break something on purpose" panel. It mirrors the real endpoint
///   POST /admin/fault/inject?type=SLOW
/// This is a StatefulWidget because it REMEMBERS which chips you selected.
class FaultSimulator extends StatefulWidget {
  FaultSimulator({super.key});

  @override
  State<FaultSimulator> createState() => _FaultSimulatorState();
}

class _FaultSimulatorState extends State<FaultSimulator> {
  String service = 'inventory-service'; // currently selected service
  FaultType fault = FaultType.dbPool; // currently selected fault

  @override
  Widget build(BuildContext context) {
    final isAdmin = sage.role == Role.admin;
    final busy = sage.pipelineRunning; // while a run is animating, lock the controls

    return Panel(
      title: 'Fault simulator',
      trailing: const Pill('mirrors /admin/fault/inject', AppColors.muted),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Break one service on purpose and watch SAGE detect it, explain it and react.',
            style: TextStyle(color: AppColors.muted, height: 1.4)),
        const SizedBox(height: 14),
        const Text('Target service',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in sage.services)
            ChoiceChip(
              label: Text(s.name),
              selected: service == s.name,
              // onSelected: null disables the chip while busy
              onSelected: busy ? null : (_) => setState(() => service = s.name),
            ),
        ]),
        const SizedBox(height: 14),
        const Text('Fault type', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in FaultType.values)
            ChoiceChip(
              label: Text(f.apiName),
              selected: fault == f,
              onSelected: busy ? null : (_) => setState(() => fault = f),
            ),
        ]),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            onPressed: (isAdmin && !busy) ? () => sage.triggerFault(service, fault) : null,
            icon: const Icon(Icons.bolt),
            label: const Text('Inject fault'),
          ),
          OutlinedButton.icon(
            onPressed: (isAdmin && !busy) ? () => sage.resetAll() : null,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset all faults'),
          ),
        ]),
        if (!isAdmin)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Viewer role is read-only. Sign in as Admin to inject faults or approve fixes.',
                style: TextStyle(color: AppColors.warn, fontSize: 12.5)),
          ),
      ]),
    );
  }
}
