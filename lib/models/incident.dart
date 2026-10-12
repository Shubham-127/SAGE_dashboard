import 'enums.dart';
import 'past_case.dart';

/// One incident = one REAL problem found by SAGE (not one alarm per service).
class Incident {
  final String id; // INC-001, INC-002 ...
  final DateTime time;
  final String rootService; // the service that is actually broken
  final List<String> affected; // services that only LOOK broken because of it
  final FaultType fault;
  final List<String> evidence; // the reasoning lines shown when you expand the card
  final String rootCause; // the AI explanation in plain English
  final double confidence; // 0.0 - 1.0
  final String action; // RESTART_POD, SCALE_UP or ROLLBACK
  final PastCase? precedent; // null = no similar old case was found
  final double similarity; // how close the best old case was
  final bool autoDecision; // true = the safety gate allowed an automatic fix
  IncidentStatus status;

  Incident({
    required this.id,
    required this.time,
    required this.rootService,
    required this.affected,
    required this.fault,
    required this.evidence,
    required this.rootCause,
    required this.confidence,
    required this.action,
    required this.precedent,
    required this.similarity,
    required this.autoDecision,
    required this.status,
  });
}
