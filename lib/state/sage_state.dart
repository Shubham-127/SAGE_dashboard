import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/incident.dart';
import '../models/past_case.dart';
import '../models/pipeline_step.dart';
import '../models/service_info.dart';

/// =====================================================================
/// SageState = the "brain" of this prototype.
///
/// It FAKES the whole SAGE backend (Kafka -> Redis -> pgvector -> AI ->
/// safety gate -> Kubernetes) so the dashboard can be shown without any
/// server. Later, the fake parts are replaced by real HTTP calls.
///
/// "extends ChangeNotifier" means: whenever we call notifyListeners(),
/// every screen that is listening redraws itself with the new data.
/// (Real-life picture: a notice board - when the notice changes, everyone
/// looking at the board sees the new notice.)
/// =====================================================================
class SageState extends ChangeNotifier {
  final Random _rnd = Random(); // makes the fake numbers wobble naturally
  Role? role; // null = nobody is logged in

  // ---------- the three demo services ----------
  // Order calls Inventory and Payment, exactly like your real services.
  final List<ServiceInfo> services = [
    ServiceInfo('order-service', 8081, 45, ['inventory-service', 'payment-service']),
    ServiceInfo('inventory-service', 8080, 30, []),
    ServiceInfo('payment-service', 8082, 55, []),
  ];

  /// Which service is currently broken, and how. Empty map = everything healthy.
  final Map<String, FaultType> faults = {};
  final Map<String, double> errorRate = {};
  final List<Incident> incidents = [];

  /// Starting knowledge base: hand-written "seed" incidents (roadmap Phase 5).
  final List<PastCase> knowledgeBase = [
    PastCase(
      title: 'DB connection pool exhausted on inventory-service',
      service: 'inventory-service',
      fault: FaultType.dbPool,
      rootCause: 'Pool of 10 connections saturated by slow queries after a traffic spike.',
      fix: 'RESTART_POD',
      source: 'Seed: March 12 incident',
    ),
    PastCase(
      title: 'Slow responses on payment-service',
      service: 'payment-service',
      fault: FaultType.slow,
      rootCause: 'Threads blocked waiting for the external payment gateway.',
      fix: 'SCALE_UP',
      source: 'Seed: April 2 incident',
    ),
    PastCase(
      title: 'Server errors after deploy on order-service',
      service: 'order-service',
      fault: FaultType.exception,
      rootCause: 'A null pointer shipped in the latest release; every order request failed.',
      fix: 'ROLLBACK',
      source: 'Seed: May 20 incident',
    ),
  ];

  List<PipelineStep> pipeline = [];
  String? pipelineIncidentId;
  bool pipelineRunning = false;
  int _counter = 0;

  // ---------- the safety-gate rules (roadmap Phase 7) ----------
  static const double similarityThreshold = 0.75; // below this = not a real match
  static const double confidenceGate = 0.85; // below this = ask a human
  static const List<String> whitelist = ['RESTART_POD', 'SCALE_UP']; // ROLLBACK may NOT auto-run

  SageState() {
    // Pre-fill 30 healthy readings so the charts are not empty at the start.
    for (final s in services) {
      for (var i = 0; i < 30; i++) {
        s.latency.add(_sample(s));
      }
      errorRate[s.name] = 0.2;
    }
    // Every second: add one new reading per service and redraw the screens.
    Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  // ---------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------
  void login(Role r) {
    role = r;
    notifyListeners();
  }

  void logout() {
    role = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // HEALTH, CASCADE AND NUMBERS
  // ---------------------------------------------------------------
  ServiceInfo _svc(String name) => services.firstWhere((s) => s.name == name);

  /// If this service is fine itself but one service it calls is broken,
  /// return that broken service's name. This is "one shop breaks, the
  /// others look broken too".
  String? cascadeSource(String name) {
    if (faults.containsKey(name)) return null;
    for (final dep in _svc(name).dependsOn) {
      if (faults.containsKey(dep)) return dep;
    }
    return null;
  }

  Health health(String name) {
    final f = faults[name];
    if (f != null) return f == FaultType.slow ? Health.degraded : Health.down;
    return cascadeSource(name) != null ? Health.degraded : Health.healthy;
  }

  /// One fake "response time" reading, based on the service's current state.
  double _sample(ServiceInfo s) {
    final jitter = 0.7 + _rnd.nextDouble() * 0.6; // 0.7 .. 1.3
    final own = faults[s.name];
    if (own == FaultType.slow) return 1800 + _rnd.nextDouble() * 300;
    if (own == FaultType.dbPool) return 2000 + _rnd.nextDouble() * 100;
    if (own == FaultType.exception) return s.baseLatency * 0.4 * jitter; // fails fast
    final src = cascadeSource(s.name);
    if (src != null) {
      if (faults[src] == FaultType.exception) return s.baseLatency * 0.6 * jitter + 20;
      return 1950 + _rnd.nextDouble() * 50; // waits until the 2-second timeout
    }
    return s.baseLatency * jitter; // healthy
  }

  double _errorFor(String name) {
    final own = faults[name];
    if (own == FaultType.slow) return 30 + _rnd.nextDouble() * 10;
    if (own != null) return 100;
    final src = cascadeSource(name);
    if (src != null) return faults[src] == FaultType.slow ? 55 + _rnd.nextDouble() * 10 : 100;
    return _rnd.nextDouble() * 0.4;
  }

  void _tick() {
    for (final s in services) {
      s.latency.add(_sample(s));
      if (s.latency.length > 30) s.latency.removeAt(0);
      errorRate[s.name] = _errorFor(s.name);
    }
    notifyListeners();
  }

  double avgLatency(String name) {
    final d = _svc(name).latency;
    final last = d.sublist(max(0, d.length - 5));
    return last.reduce((a, b) => a + b) / last.length;
  }

  int get healthyCount => services.where((s) => health(s.name) == Health.healthy).length;

  int get openIncidents => incidents
      .where((i) => i.status == IncidentStatus.awaitingApproval || i.status == IncidentStatus.executing)
      .length;

  int get autoHealedCount => incidents.where((i) => i.status == IncidentStatus.autoHealed).length;

  // ---------------------------------------------------------------
  // RAG: "search the old case files"
  // The real system compares embeddings in pgvector. Here we imitate it:
  //   same kind of symptom -> +0.43,  same service -> +0.35,  plus a small base.
  // An exact match scores about 0.90+, the same symptom on another service ~0.55.
  // ---------------------------------------------------------------
  CaseMatch _bestMatch(String service, FaultType fault) {
    PastCase? best;
    var bestScore = 0.0;
    for (final c in knowledgeBase) {
      var score = 0.12;
      if (c.fault == fault) score += 0.43;
      if (c.service == service) score += 0.35;
      score += min(c.timesSeen, 5) * 0.01; // cases seen more often are trusted slightly more
      score += (c.title.length % 5) * 0.004; // tiny wobble so numbers look natural
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return CaseMatch(best, min(bestScore, 0.99));
  }

  String _actionFor(FaultType f) => switch (f) {
        FaultType.slow => 'SCALE_UP',
        FaultType.exception => 'ROLLBACK',
        FaultType.dbPool => 'RESTART_POD',
      };

  /// The "AI explanation" text for each kind of fault.
  String _causeFor(String svc, FaultType f) => switch (f) {
        FaultType.slow =>
          '$svc is saturated: responses take about 2 seconds instead of milliseconds, most likely CPU or thread starvation.',
        FaultType.exception =>
          '$svc returns HTTP 500 on every request, consistent with a bad release or a broken dependency.',
        FaultType.dbPool =>
          '$svc ran out of database connections: requests wait several seconds, then fail.',
      };

  String _kubectl(Incident inc) => switch (inc.action) {
        'RESTART_POD' => 'kubectl rollout restart deployment/${inc.rootService}',
        'SCALE_UP' => 'kubectl scale deployment/${inc.rootService} --replicas=3',
        _ => 'kubectl rollout undo deployment/${inc.rootService}',
      };

  // ---------------------------------------------------------------
  // THE PIPELINE ANIMATION
  // ---------------------------------------------------------------

  /// Marks step [i] as "running", waits a moment, then fills in its result.
  Future<void> _step(int i, String Function() work) async {
    pipeline[i].state = StepState.running;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 750));
    pipeline[i].detail = work();
    pipeline[i].state = StepState.done;
    notifyListeners();
  }

  /// The big one: inject a fault and walk through every SAGE stage.
  Future<void> triggerFault(String service, FaultType fault) async {
    if (pipelineRunning || role != Role.admin) return;
    pipelineRunning = true;
    pipelineIncidentId = null;
    pipeline = [
      PipelineStep('1. Fault injected'),
      PipelineStep('2. Kafka metric stream'),
      PipelineStep('3. Redis anomaly detection'),
      PipelineStep('4. Incident correlation'),
      PipelineStep('5. pgvector similarity search'),
      PipelineStep('6. Spring AI diagnosis'),
      PipelineStep('7. Safety gate'),
      PipelineStep('8. Kubernetes operator'),
    ];
    notifyListeners();

    // Work out everything up front; the animation only REVEALS it step by step.
    final base = _svc(service).baseLatency.round();
    final affected =
        services.where((s) => s.dependsOn.contains(service)).map((s) => s.name).toList();
    final zScore = (5 + _rnd.nextDouble() * 4).toStringAsFixed(1);
    final match = _bestMatch(service, fault);
    final precedent = match.score >= similarityThreshold ? match.best : null;
    final confidence =
        precedent != null ? 0.90 + _rnd.nextDouble() * 0.06 : 0.62 + _rnd.nextDouble() * 0.10;
    final action = precedent?.fix ?? _actionFor(fault);
    final whitelisted = whitelist.contains(action);
    final confident = confidence >= confidenceGate;
    final auto = whitelisted && confident; // <-- the safety-gate decision
    final pct = (confidence * 100).round();
    final gateReason = auto
        ? '$action is whitelisted and confidence $pct% is at least 85%, so AUTO_EXECUTE'
        : (!confident
            ? 'Confidence $pct% is below 85%, so ESCALATE_TO_HUMAN'
            : '$action is not on the auto-fix whitelist, so ESCALATE_TO_HUMAN');

    final evidence = <String>[
      switch (fault) {
        FaultType.slow => 'responseTimeMs is about 2000 ms vs baseline $base ms (z-score $zScore)',
        FaultType.exception => 'status=ERROR on 100% of recent events vs 0% baseline (z-score $zScore)',
        FaultType.dbPool =>
          'responseTimeMs about 8000 ms, then status=ERROR: the usual pool-exhaustion shape (z-score $zScore)',
      },
      if (affected.isNotEmpty)
        '${affected.join(", ")} is also anomalous, but it calls $service: a symptom, not the cause',
      precedent != null
          ? 'pgvector matched "${precedent.title}" (similarity ${match.score.toStringAsFixed(2)}, threshold 0.75)'
          : 'No past case reached 0.75 (best ${match.score.toStringAsFixed(2)}). Reasoning from raw signals and general knowledge.',
      'Safety gate: $gateReason',
    ];

    // ---- reveal the 8 steps one by one ----
    await _step(0, () {
      faults[service] = fault; // the service now really "breaks" on screen
      return 'POST /admin/fault/inject?type=${fault.apiName} on $service';
    });
    await _step(1, () => 'sage.metrics topic: ${30 + _rnd.nextInt(30)} events/s from ${services.length} services');
    await _step(2, () => 'z-score $zScore is above the 3.0 threshold on $service');
    await _step(
        3,
        () => affected.isEmpty
            ? 'No other service affected, root cause candidate: $service'
            : '${affected.join(", ")} also anomalous but depends on $service: 1 incident, root = $service');
    await _step(
        4,
        () => precedent != null
            ? 'Best match ${match.score.toStringAsFixed(2)} is above 0.75, using "${precedent.title}"'
            : 'Best match ${match.score.toStringAsFixed(2)} is below 0.75: no precedent');
    await _step(5, () => 'Diagnosis ready, confidence $pct%');

    final incident = Incident(
      id: 'INC-${(++_counter).toString().padLeft(3, '0')}',
      time: DateTime.now(),
      rootService: service,
      affected: affected,
      fault: fault,
      evidence: evidence,
      rootCause: precedent != null
          ? '${_causeFor(service, fault)} This matches a previous incident.'
          : _causeFor(service, fault),
      confidence: confidence,
      action: action,
      precedent: precedent,
      similarity: match.score,
      autoDecision: auto,
      status: auto ? IncidentStatus.executing : IncidentStatus.awaitingApproval,
    );

    await _step(6, () => gateReason);
    incidents.insert(0, incident);
    pipelineIncidentId = incident.id;

    if (auto) {
      await _runOperator(incident); // the "robot" fixes it by itself
    } else {
      pipeline[7].detail = 'Waiting for an admin to approve or dismiss';
    }
    pipelineRunning = false;
    notifyListeners();
  }

  /// Step 8: the Kubernetes operator carries out the fix.
  Future<void> _runOperator(Incident inc) async {
    _setOperator(inc, StepState.running, 'Executing ${inc.action} on ${inc.rootService}...');
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1500));
    _setOperator(inc, StepState.done, _kubectl(inc));
    _resolve(inc);
    notifyListeners();
  }

  void _setOperator(Incident inc, StepState s, String detail) {
    if (pipelineIncidentId == inc.id && pipeline.length == 8) {
      pipeline[7].state = s;
      pipeline[7].detail = detail;
    }
  }

  /// The service heals, and the LEARNING LOOP saves the case (roadmap Phase 9).
  void _resolve(Incident inc) {
    faults.remove(inc.rootService);
    inc.status = inc.autoDecision ? IncidentStatus.autoHealed : IncidentStatus.resolved;
    final p = inc.precedent;
    if (p != null) {
      p.timesSeen++; // known pattern: just strengthen it
    } else {
      // brand-new pattern: add a new case file so next time it IS a precedent
      knowledgeBase.insert(
        0,
        PastCase(
          title: '${inc.fault.title} on ${inc.rootService}',
          service: inc.rootService,
          fault: inc.fault,
          rootCause: inc.rootCause,
          fix: inc.action,
          source: 'Learned from ${inc.id}',
        ),
      );
    }
  }

  // ---------------------------------------------------------------
  // BUTTONS A HUMAN CAN PRESS (admin only)
  // ---------------------------------------------------------------

  /// "Approve fix"
  Future<void> approve(Incident inc) async {
    if (role != Role.admin || inc.status != IncidentStatus.awaitingApproval) return;
    inc.status = IncidentStatus.executing;
    await _runOperator(inc);
  }

  /// "Dismiss": nothing gets fixed.
  void dismiss(Incident inc) {
    if (role != Role.admin || inc.status != IncidentStatus.awaitingApproval) return;
    inc.status = IncidentStatus.dismissed;
    _setOperator(inc, StepState.pending, 'Dismissed by admin: no action taken');
    notifyListeners();
  }

  /// Heal everything (same as POST /admin/fault/clear on every service).
  void resetAll() {
    if (pipelineRunning) return;
    faults.clear();
    for (final i in incidents) {
      if (i.status == IncidentStatus.awaitingApproval) i.status = IncidentStatus.dismissed;
    }
    pipeline = [];
    notifyListeners();
  }
}

/// ONE shared instance. Every screen reads from this same object.
final SageState sage = SageState();
