import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../state/sage_state.dart';
import '../widgets/fault_simulator.dart';
import '../widgets/incident_card.dart';
import '../widgets/kpi.dart';
import '../widgets/panel.dart';
import '../widgets/pipeline_panel.dart';
import '../widgets/responsive_grid.dart';
import '../widgets/service_card.dart';

/// The main screen (the "control room"). From top to bottom:
///   1. four big numbers   2. service cards   3. fault simulator + live pipeline
///   4. latest incidents
class OverviewPage extends StatelessWidget {
  OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final total = sage.services.length;
    final healthy = sage.healthyCount;

    return LayoutBuilder(builder: (context, c) {
      final twoCol = c.maxWidth >= 980; // side by side on wide screens
      final simulator = FaultSimulator();
      final pipeline = PipelinePanel();

      return Column(children: [
        if (!sage.online) ...[
          const Panel(
            title: 'Detector offline',
            child: Text(
                'The dashboard cannot reach http://localhost:8090. Start detector-service and this page recovers by itself.',
                style: TextStyle(color: AppColors.bad, height: 1.4)),
          ),
          const SizedBox(height: 16),
        ] else if (sage.allIdle) ...[
          const Panel(
            title: 'Detector is up, but no traffic is arriving',
            child: Text(
                'All services are idle. Check that Inventory, Order and Payment are running; the detector sends a test order every 2 seconds.',
                style: TextStyle(color: AppColors.warn, height: 1.4)),
          ),
          const SizedBox(height: 16),
        ],
        // 1. the four numbers
        ResponsiveGrid(maxCols: 4, children: [
          Kpi('Services healthy', '$healthy of $total',
              healthy == total ? AppColors.good : AppColors.warn),
          Kpi('Open incidents', '${sage.openIncidents}',
              sage.openIncidents > 0 ? AppColors.warn : AppColors.good),
          Kpi('Auto-healed', '${sage.autoHealedCount}', AppColors.good),
          Kpi('Past cases known', '${sage.knowledgeBase.length}', AppColors.accent),
        ]),
        const SizedBox(height: 16),

        // 2. the three service cards
        Panel(
          title: 'Services',
          trailing: const Text('order-service calls inventory and payment',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          child: ResponsiveGrid(
            maxCols: 3,
            children: sage.services.map((s) => ServiceCard(s)).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // 3. simulator and pipeline (side by side, or stacked on small screens)
        if (twoCol)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: simulator),
            const SizedBox(width: 16),
            Expanded(child: pipeline),
          ])
        else
          Column(children: [simulator, const SizedBox(height: 16), pipeline]),
        const SizedBox(height: 16),

        // 4. newest three incidents
        Panel(
          title: 'Latest incidents',
          child: IncidentList(
            items: sage.incidents.take(3).toList(),
            emptyText: 'No incidents yet. Inject a fault above and watch SAGE respond.',
          ),
        ),
      ]);
    });
  }
}
