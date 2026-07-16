// crew_core/lib/src/runner/fake_runner.dart
import '../models/agent_template.dart';
import 'runner.dart';

/// Default canned distill output used when no distill responder is provided.
const String _defaultDistillOutput =
    '{"domainNotes":"领域抽象笔记","playbooks":'
    '[{"path":"排查-通用模式.md","content":"通用排查步骤"}]}';

class FakeRunner implements Runner {
  final String Function(String workingDir, AgentTemplate template) responder;
  final String Function(String prompt)? _distillResponder;

  FakeRunner(this.responder, {String Function(String prompt)? distillResponder})
      : _distillResponder = distillResponder;

  @override
  Future<RunnerResult> probe({
    required String workingDir,
    required String prompt,
    required AgentTemplate template,
  }) async {
    return RunnerResult(responder(workingDir, template), 0);
  }

  @override
  Future<RunnerResult> distill({required String prompt}) async {
    final out = _distillResponder != null
        ? _distillResponder!(prompt)
        : _defaultDistillOutput;
    return RunnerResult(out, 0);
  }
}
