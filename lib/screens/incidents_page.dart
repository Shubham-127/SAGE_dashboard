import 'package:flutter/material.dart';
import '../state/sage_state.dart';
import '../widgets/incident_card.dart';
import '../widgets/panel.dart';

/// Full history of every incident SAGE has handled in this session.
class IncidentsPage extends StatelessWidget {
  IncidentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'All incidents (${sage.incidents.length})',
      child: IncidentList(
        items: sage.incidents,
        emptyText: 'No incidents yet. Go to Overview and inject a fault.',
      ),
    );
  }
}
