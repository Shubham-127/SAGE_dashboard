/// ENUMS = a fixed list of allowed choices.
/// Example: a service can only be healthy, degraded or down - nothing else.

enum Health { healthy, degraded, down }

/// The three faults we can inject.
/// Same names as the FaultType enum in your real Inventory service.
enum FaultType { slow, exception, dbPool }

enum IncidentStatus { awaitingApproval, executing, autoHealed, resolved, dismissed }

/// Who is logged in. Admin can act, Viewer can only watch.
enum Role { viewer, admin }

/// State of one step in the live pipeline panel.
enum StepState { pending, running, done }

/// An "extension" adds extra abilities to an existing type.
/// Here we give every FaultType two text helpers: apiName and title.
extension FaultTypeText on FaultType {
  /// The word used in the real endpoint: /admin/fault/inject?type=SLOW
  String get apiName => switch (this) {
        FaultType.slow => 'SLOW',
        FaultType.exception => 'EXCEPTION',
        FaultType.dbPool => 'DB_POOL_EXHAUSTED',
      };

  /// Plain-English name shown to humans.
  String get title => switch (this) {
        FaultType.slow => 'Slow responses',
        FaultType.exception => 'Server errors (HTTP 500)',
        FaultType.dbPool => 'DB connection pool exhausted',
      };
}
