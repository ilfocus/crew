import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  test('claude tool builds `claude -p <prompt>` in workingDir', () async {
    String? seenExe;
    List<String>? seenArgs;
    String? seenCwd;
    final runner = CliRunner(
      tool: 'claude',
      processRunner: (exe, args, {workingDirectory}) async {
        seenExe = exe;
        seenArgs = args;
        seenCwd = workingDirectory;
        return const ProcessResultLite(0, '{"role":"ok"}', '');
      },
    );
    final r = await runner.probe(
      workingDir: '/repo', prompt: 'PROMPT', template: kBuiltinTemplates.first,
    );
    expect(seenExe, 'claude');
    expect(seenArgs, ['-p', 'PROMPT']);
    expect(seenCwd, '/repo');
    expect(r.rawOutput, contains('ok'));
  });

  test('codex tool builds `codex exec <prompt>`', () async {
    List<String>? seenArgs;
    final runner = CliRunner(
      tool: 'codex',
      processRunner: (exe, args, {workingDirectory}) async {
        seenArgs = args;
        return const ProcessResultLite(0, '{}', '');
      },
    );
    await runner.probe(workingDir: '/r', prompt: 'P', template: kBuiltinTemplates.first);
    expect(seenArgs, ['exec', 'P']);
  });

  test('non-zero exit is surfaced in RunnerResult', () async {
    final runner = CliRunner(
      tool: 'claude',
      processRunner: (exe, args, {workingDirectory}) async =>
          const ProcessResultLite(1, '', 'boom'),
    );
    final r = await runner.probe(workingDir: '/r', prompt: 'P', template: kBuiltinTemplates.first);
    expect(r.ok, isFalse);
    expect(r.exitCode, 1);
  });
}
