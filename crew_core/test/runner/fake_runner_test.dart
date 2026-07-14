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
}
