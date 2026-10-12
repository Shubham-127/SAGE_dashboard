import 'enums.dart';

/// One line in the "Live pipeline" panel (for example "3. Redis anomaly detection").
class PipelineStep {
  final String title;
  String detail = ''; // filled in when the step finishes
  StepState state = StepState.pending;

  PipelineStep(this.title);
}
