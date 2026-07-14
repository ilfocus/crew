// crew_core/lib/src/runner/runner.dart
import '../models/agent_template.dart';

class RunnerResult {
  final String rawOutput;
  final int exitCode;
  const RunnerResult(this.rawOutput, this.exitCode);
  bool get ok => exitCode == 0;
}

abstract class Runner {
  Future<RunnerResult> probe({
    required String workingDir,
    required String prompt,
    required AgentTemplate template,
  });
}
