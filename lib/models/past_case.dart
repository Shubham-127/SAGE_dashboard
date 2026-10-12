import 'enums.dart';

/// One "old case file" in the knowledge base.
/// In the real system this row lives in PostgreSQL with a pgvector column.
class PastCase {
  final String title;
  final String service;
  final FaultType fault;
  final String rootCause;
  final String fix; // e.g. RESTART_POD
  final String source; // where it came from: a seed, or "Learned from INC-002"
  int timesSeen; // how many times this pattern has happened

  PastCase({
    required this.title,
    required this.service,
    required this.fault,
    required this.rootCause,
    required this.fix,
    required this.source,
    this.timesSeen = 1,
  });
}

/// Result of "search the case files": the best case found + how similar it is (0 to 1).
class CaseMatch {
  final PastCase? best;
  final double score;
  CaseMatch(this.best, this.score);
}
