// crew_core/lib/src/runner/fake_runner.dart
import '../models/agent_template.dart';
import 'runner.dart';

class FakeRunner implements Runner {
  final String Function(String workingDir, AgentTemplate template) responder;
  FakeRunner(this.responder);

  @override
  Future<RunnerResult> probe({
    required String workingDir,
    required String prompt,
    required AgentTemplate template,
  }) async {
    return RunnerResult(responder(workingDir, template), 0);
  }
}
