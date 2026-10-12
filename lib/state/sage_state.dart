import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/enums.dart';
import '../models/incident.dart';
import '../models/past_case.dart';
import '../models/pipeline_step.dart';
import '../models/service_info.dart';

/// Where the detector-service (the "doctor") listens.
const String detectorApi = 'http://localhost:8090/api';

/// =====================================================================
/// SageState = the "brain" of the dashboard.
///
/// LIVE now: every second it asks the detector for
///   GET /api/services    -> health, latency, error rate, who is root/symptom
///   GET /api/incidents   -> incidents found by the detector
/// and the buttons call
///   POST /api/faults/{service}/inject?type=SLOW|EXCEPTION|DB_POOL_EXHAUSTED
///   POST /api/faults/{service}/clear
///
/// STILL SIMULATED (not built yet): pgvector similarity search, Spring AI
/// diagnosis, the confidence score, the safety-gate decision and the
/// Kubernetes command text. They are computed here so the full story shows.
///
/// "extends ChangeNotifier": calling notifyListeners() redraws every screen.
/// =====================================================================
class SageState extends ChangeNotifier {
  final Random _rnd = Random();
  Role? role; // null = nobody is logged in
  bool online = false; // can we reach the detector right now?

  // ---------- the three services (names, ports and who-calls-whom) ----------
  final List<ServiceInfo> services = [
    ServiceInfo('order-service', 8081, 45, ['inventory-service', 'payment-service']),
    ServiceInfo('inventory-service', 8080, 30, []),
    ServiceInfo('payment-service', 8082, 55, []),
  ];

  // Latest facts from the detector, per service name.
  final Map<String, String> _healthText = {}; // idle / healthy / degraded / down
  final Map<String, String> _roleText = {}; // ok / symptom / root
  final Map<String, double> _avg = {};
  final Map<String, double> errorRate = {};

  // Which fault WE injected from this dashboard (so incidents show the right name).
  final Map<String, FaultType> _injected = {};

  final List<Incident> incidents = [];
  final Map<String, Incident> _byId = {};
  final Set<String> _learned = {};
  final Set<String> _operatorBusy = {};

  /// Starting knowledge base: hand-written "seed" incidents (simulated pgvector).
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
  bool _polling = false;

  // ---------- the safety-gate rules ----------
  static const double similarityThreshold = 0.75; // below this = not a real match
  static const double confidenceGate = 0.85; // below this = ask a human
  static const List<String> whitelist = ['RESTART_POD', 'SCALE_UP']; // ROLLBACK may NOT auto-run

  SageState() {
    for (final s in services) {
      errorRate[s.name] = 0;
      _avg[s.name] = 0;
    }
    _poll();
    // Every second: ask the detector for fresh data.
    Timer.periodic(const Duration(seconds: 1), (_) => _poll());
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
  // TALKING TO THE DETECTOR
  // ---------------------------------------------------------------
  Future<void> _poll() async {
    if (_polling) return; // do not start a new round while the last one is still running
    _polling = true;
    try {
      final sRes = await http
          .get(Uri.parse('$detectorApi/services'))
          .timeout(const Duration(seconds: 3));
      final iRes = await http
          .get(Uri.parse('$detectorApi/incidents'))
          .timeout(const Duration(seconds: 3));
      _applyServices(jsonDecode(sRes.body) as List<dynamic>);
      _applyIncidents(jsonDecode(iRes.body) as List<dynamic>);
      online = true;
    } catch (_) {
      online = false;
    }
    _polling = false;
    notifyListeners();
  }

  void _applyServices(List<dynamic> list) {
    for (final raw in list) {
      final m = raw as Map<String, dynamic>;
      final name = m['name'] as String;
      final idx = services.indexWhere((s) => s.name == name);
      if (idx < 0) continue;
      _healthText[name] = m['health'] as String;
      _roleText[name] = m['role'] as String;
      _avg[name] = (m['avgMs'] as num).toDouble();
      errorRate[name] = (m['errorPct'] as num).toDouble();
      final s = services[idx];
      s.latency
        ..clear()
        ..addAll((m['history'] as List<dynamic>).map((e) => (e as num).toDouble()));
    }
  }

  void _applyIncidents(List<dynamic> list) {
    final ordered = <Incident>[];
    for (final raw in list) {
      final m = raw as Map<String, dynamic>;
      final id = m['id'] as String;
      final detectorOpen = m['status'] == 'OPEN';
      var inc = _byId[id];
      if (inc == null) {
        // First time we see this incident: add our (simulated) AI layer on top.
        inc = _buildIncident(m, detectorOpen);
        _byId[id] = inc;
        // A fault injected from outside the dashboard (for example curl): auto-fix if the gate allows.
        if (detectorOpen && inc.autoDecision && !pipelineRunning) {
          _runOperator(inc);
        }
      } else if (!detectorOpen &&
          (inc.status == IncidentStatus.awaitingApproval || inc.status == IncidentStatus.executing) &&
          !_operatorBusy.contains(id)) {
        _finish(inc); // fixed from outside, for example "Reset all faults"
      }
      ordered.add(inc);
    }
    incidents
      ..clear()
      ..addAll(ordered);
  }

  // ---------------------------------------------------------------
  // HEALTH AND NUMBERS (read from the detector's latest answer)
  // ---------------------------------------------------------------
  ServiceInfo _svc(String name) => services.firstWhere((s) => s.name == name);

  bool _isBroken(String name) => _healthText[name] == 'degraded' || _healthText[name] == 'down';

  /// If this service only LOOKS broken because something it calls is broken,
  /// return that broken service's name (the detector's "symptom" verdict).
  String? cascadeSource(String name) {
    if (_roleText[name] != 'symptom') return null;
    for (final dep in _svc(name).dependsOn) {
      if (_isBroken(dep)) return dep;
    }
    return null;
  }

  Health health(String name) {
    final h = _healthText[name];
    if (h == 'down') return Health.down;
    if (h == 'degraded') return Health.degraded;
    if (h == 'healthy') return Health.healthy;
    return Health.idle; // no readings yet, or detector offline
  }

  double avgLatency(String name) => _avg[name] ?? 0;

  int get healthyCount => services.where((s) => health(s.name) == Health.healthy).length;

  bool get allIdle => services.every((s) => health(s.name) == Health.idle);

  int get openIncidents => incidents
      .where((i) => i.status == IncidentStatus.awaitingApproval || i.status == IncidentStatus.executing)
      .length;

  int get autoHealedCount => incidents.where((i) => i.status == IncidentStatus.autoHealed).length;

  // ---------------------------------------------------------------
  // RAG: "search the old case files" (simulated pgvector)
  // ---------------------------------------------------------------
  CaseMatch _bestMatch(String service, FaultType fault) {
    PastCase? best;
    var bestScore = 0.0;
    for (final c in knowledgeBase) {
      var score = 0.12;
      if (c.fault == fault) score += 0.43;
      if (c.service == service) score += 0.35;
      score += min(c.timesSeen, 5) * 0.01;
      score += (c.title.length % 5) * 0.004;
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return CaseMatch(best, min(bestScore, 0.99));
  }

  String _causeFor(String svc, FaultType f) => switch (f) {
        FaultType.slow =>
          '$svc is saturated: responses take far longer than normal, most likely CPU or thread starvation.',
        FaultType.exception =>
          '$svc returns HTTP 500 on most requests, consistent with a bad release or a broken dependency.',
        FaultType.dbPool =>
          '$svc ran out of database connections: requests wait several seconds, then fail.',
      };

  String _kubectl(Incident inc) => switch (inc.action) {
        'RESTART_POD' => 'kubectl rollout restart deployment/${inc.rootService}',
        'SCALE_UP' => 'kubectl scale deployment/${inc.rootService} --replicas=3',
        _ => 'kubectl rollout undo deployment/${inc.rootService}',
      };

  bool _isAuto(String action, double confidence) =>
      whitelist.contains(action) && confidence >= confidenceGate;

  String _gateText(String action, double confidence) {
    final pct = (confidence * 100).round();
    if (_isAuto(action, confidence)) {
      return '$action is whitelisted and confidence $pct% is at least 85%, so AUTO_EXECUTE';
    }
    if (confidence < confidenceGate) {
      return 'Confidence $pct% is below 85%, so ESCALATE_TO_HUMAN';
    }
    return '$action is not on the auto-fix whitelist, so ESCALATE_TO_HUMAN';
  }

  /// Turns one detector incident (JSON) into our richer Incident object.
  Incident _buildIncident(Map<String, dynamic> m, bool detectorOpen) {
    final id = m['id'] as String;
    final root = m['rootService'] as String;
    final affected = (m['affected'] as List<dynamic>).cast<String>();
    final detectorEvidence = (m['evidence'] as List<dynamic>).cast<String>();
    final detectorAction = m['suggestedAction'] as String;

    // The detector does not know the fault NAME, so use what we injected, else guess from the action.
    final fault = _injected[root] ??
        (detectorAction == 'RESTART_POD' ? FaultType.exception : FaultType.slow);

    final match = _bestMatch(root, fault);
    final precedent = match.score >= similarityThreshold ? match.best : null;
    final confidence =
        precedent != null ? 0.90 + _rnd.nextDouble() * 0.06 : 0.62 + _rnd.nextDouble() * 0.10;
    final action = precedent?.fix ?? detectorAction;
    final auto = _isAuto(action, confidence);

    final evidence = <String>[
      ...detectorEvidence, // LIVE reasoning from the detector
      precedent != null
          ? 'Knowledge base (simulated pgvector): matched "${precedent.title}" (similarity ${match.score.toStringAsFixed(2)}, threshold 0.75)'
          : 'Knowledge base (simulated pgvector): no past case reached 0.75 (best ${match.score.toStringAsFixed(2)}). Reasoning from raw signals only.',
      'Safety gate: ${_gateText(action, confidence)}',
    ];

    final opened = DateTime.tryParse(m['openedAt'] as String)?.toLocal() ?? DateTime.now();
    final status = !detectorOpen
        ? IncidentStatus.resolved
        : (auto ? IncidentStatus.executing : IncidentStatus.awaitingApproval);
    if (!detectorOpen) _learned.add(id); // already history, do not learn from it again

    return Incident(
      id: id,
      time: opened,
      rootService: root,
      affected: affected,
      fault: fault,
      evidence: evidence,
      rootCause: precedent != null
          ? '${_causeFor(root, fault)} This matches a previous incident.'
          : _causeFor(root, fault),
      confidence: confidence,
      action: action,
      precedent: precedent,
      similarity: match.score,
      autoDecision: auto,
      status: status,
    );
  }

  // ---------------------------------------------------------------
  // THE LIVE PIPELINE
  // Steps 1-4 wait for REAL things to happen. Steps 5-7 are the simulated AI layer.
  // ---------------------------------------------------------------
  Future<void> _reveal(int i, String Function() work) async {
    pipeline[i].state = StepState.running;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 750));
    pipeline[i].detail = work();
    pipeline[i].state = StepState.done;
    notifyListeners();
  }

  /// Waits until [cond] is true. Returns false if it takes longer than [seconds].
  Future<bool> _waitUntil(bool Function() cond, {int seconds = 40}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      if (cond()) return true;
      await Future.delayed(const Duration(milliseconds: 400));
    }
    return cond();
  }

  void _stopPipeline(int step, String message) {
    pipeline[step].state = StepState.pending;
    pipeline[step].detail = message;
    pipelineRunning = false;
    notifyListeners();
  }

  /// Inject a REAL fault, then watch the real detector find it.
  Future<void> triggerFault(String service, FaultType fault) async {
    if (pipelineRunning || role != Role.admin) return;
    pipelineRunning = true;
    pipelineIncidentId = null;
    pipeline = [
      PipelineStep('1. Fault injected'),
      PipelineStep('2. Kafka metric stream'),
      PipelineStep('3. Anomaly detection'),
      PipelineStep('4. Incident correlation'),
      PipelineStep('5. pgvector similarity search (simulated)'),
      PipelineStep('6. Spring AI diagnosis (simulated)'),
      PipelineStep('7. Safety gate'),
      PipelineStep('8. Fix (stands in for the Kubernetes operator)'),
    ];
    final knownIds = _byId.keys.toSet(); // incidents that existed before this run
    notifyListeners();

    // ---- 1. real: call the service's fault switch through the detector ----
    pipeline[0].state = StepState.running;
    notifyListeners();
    try {
      final r = await http
          .post(Uri.parse('$detectorApi/faults/$service/inject?type=${fault.apiName}'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) throw Exception(r.body);
    } catch (e) {
      _stopPipeline(0, 'Could not inject: $e');
      return;
    }
    _injected[service] = fault;
    pipeline[0].state = StepState.done;
    pipeline[0].detail = 'POST /admin/fault/inject?type=${fault.apiName} on $service (live)';
    notifyListeners();

    // ---- 2. real: metrics are flowing from Kafka ----
    await _reveal(1, () => 'sage.metrics: ${_svc(service).latency.length} recent readings for $service (live)');

    // ---- 3. real: wait until the detector flags the service ----
    pipeline[2].state = StepState.running;
    notifyListeners();
    final flagged = await _waitUntil(() => _isBroken(service));
    if (!flagged) {
      _stopPipeline(2, 'The detector did not flag $service. Is traffic reaching it?');
      return;
    }
    pipeline[2].state = StepState.done;
    pipeline[2].detail =
        '$service: average ${avgLatency(service).round()} ms, errors ${errorRate[service]!.round()}% (live)';
    notifyListeners();

    // ---- 4. real: wait for the detector to open ONE incident with the true root ----
    pipeline[3].state = StepState.running;
    pipeline[3].detail = 'Confirming the culprit for 10 seconds before opening an incident...';
    notifyListeners();
    final found = await _waitUntil(
        () => incidents.any((i) => i.rootService == service && !knownIds.contains(i.id)),
        seconds: 45);
    if (!found) {
      _stopPipeline(3, 'No incident opened. Try again.');
      return;
    }
    final inc = incidents.firstWhere((i) => i.rootService == service && !knownIds.contains(i.id));
    pipeline[3].state = StepState.done;
    pipeline[3].detail = inc.affected.isEmpty
        ? 'No other service affected, root cause: $service (live)'
        : '${inc.affected.join(", ")} also anomalous but depends on $service: 1 incident, root = $service (live)';
    notifyListeners();

    // ---- 5-7: the simulated AI layer ----
    await _reveal(
        4,
        () => inc.precedent != null
            ? 'Best match ${inc.similarity.toStringAsFixed(2)} is above 0.75, using "${inc.precedent!.title}"'
            : 'Best match ${inc.similarity.toStringAsFixed(2)} is below 0.75: no precedent');
    await _reveal(5, () => 'Diagnosis ready, confidence ${(inc.confidence * 100).round()}%');
    await _reveal(6, () => _gateText(inc.action, inc.confidence));
    pipelineIncidentId = inc.id;

    if (inc.autoDecision) {
      await _runOperator(inc); // the "robot" fixes it by itself
    } else {
      pipeline[7].detail = 'Waiting for an admin to approve or dismiss';
    }
    pipelineRunning = false;
    notifyListeners();
  }

  /// Step 8: carry out the fix. In this prototype that means clearing the fault for real.
  Future<void> _runOperator(Incident inc) async {
    if (!_operatorBusy.add(inc.id)) return;
    inc.status = IncidentStatus.executing;
    _setOperator(inc, StepState.running, 'Executing ${inc.action} on ${inc.rootService}...');
    notifyListeners();

    var ok = true;
    try {
      final r = await http
          .post(Uri.parse('$detectorApi/faults/${inc.rootService}/clear'))
          .timeout(const Duration(seconds: 5));
      ok = r.statusCode == 200;
    } catch (_) {
      ok = false;
    }
    await Future.delayed(const Duration(milliseconds: 1200));

    if (ok) {
      _setOperator(inc, StepState.done, '${_kubectl(inc)}  (prototype: clears the injected fault)');
      _finish(inc);
    } else {
      inc.status = IncidentStatus.awaitingApproval;
      _setOperator(inc, StepState.pending, 'Could not reach ${inc.rootService}. Press Approve fix to retry.');
    }
    _operatorBusy.remove(inc.id);
    notifyListeners();
  }

  void _setOperator(Incident inc, StepState s, String detail) {
    if (pipelineIncidentId == inc.id && pipeline.length == 8) {
      pipeline[7].state = s;
      pipeline[7].detail = detail;
    }
  }

  /// The service healed. Mark the incident and run the LEARNING LOOP once.
  void _finish(Incident inc) {
    inc.status = inc.autoDecision ? IncidentStatus.autoHealed : IncidentStatus.resolved;
    _injected.remove(inc.rootService);
    if (!_learned.add(inc.id)) return;
    final p = inc.precedent;
    if (p != null) {
      p.timesSeen++; // known pattern: just strengthen it
    } else {
      // brand-new pattern: add a case file so next time it IS a precedent
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
    await _runOperator(inc);
  }

  /// "Dismiss": nothing gets fixed.
  void dismiss(Incident inc) {
    if (role != Role.admin || inc.status != IncidentStatus.awaitingApproval) return;
    inc.status = IncidentStatus.dismissed;
    _setOperator(inc, StepState.pending, 'Dismissed by admin: no action taken');
    notifyListeners();
  }

  /// Heal everything: POST /clear on every service that has a fault switch.
  Future<void> resetAll() async {
    if (pipelineRunning) return;
    for (final name in ['inventory-service', 'payment-service']) {
      try {
        await http
            .post(Uri.parse('$detectorApi/faults/$name/clear'))
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    _injected.clear();
    pipeline = [];
    notifyListeners();
  }
}

/// ONE shared instance. Every screen reads from this same object.
final SageState sage = SageState();
