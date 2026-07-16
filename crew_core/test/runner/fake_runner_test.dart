// crew_core/test/runner/fake_runner_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  test('FakeRunner returns responder output with exit 0', () async {
    final runner = FakeRunner((dir, t) => '{"role":"${t.role}"}');
    final r = await runner.probe(
      workingDir: '/x',
      prompt: 'go',
      template: kBuiltinTemplates.first,
    );
    expect(r.ok, isTrue);
    expect(r.rawOutput, contains('"role"'));
  });

  test('FakeRunner.distill returns parseable JSON by default', () async {
    final runner = FakeRunner((dir, t) => '{}');
    final r = await runner.distill(prompt: 'go');
    expect(r.ok, isTrue);
    expect(r.exitCode, 0);
    final parsed = parseDistill(r.rawOutput);
    expect(parsed.domainNotes, '领域抽象笔记');
    expect(parsed.playbooks.length, 1);
    expect(parsed.playbooks.first.path, '排查-通用模式.md');
    expect(parsed.playbooks.first.content, '通用排查步骤');
  });

  test('FakeRunner.distill uses injected distill responder when provided',
      () async {
    final runner = FakeRunner(
      (dir, t) => '{}',
      distillResponder: (prompt) =>
          '{"domainNotes":"custom:$prompt","playbooks":[]}',
    );
    final r = await runner.distill(prompt: 'PROMPT');
    expect(r.ok, isTrue);
    final parsed = parseDistill(r.rawOutput);
    expect(parsed.domainNotes, 'custom:PROMPT');
    expect(parsed.playbooks, isEmpty);
  });
}
