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

  test('distill no longer throws UnimplementedError and calls tool with prompt', () async {
    String? seenExe;
    List<String>? seenArgs;
    Object? seenCwd = Object();
    final runner = CliRunner(
      tool: 'claude',
      processRunner: (exe, args, {workingDirectory}) async {
        seenExe = exe;
        seenArgs = args;
        seenCwd = workingDirectory;
        return const ProcessResultLite(0, '{"domainNotes":"d","playbooks":[]}', '');
      },
    );
    final r = await runner.distill(prompt: 'DISTILL_PROMPT');
    expect(seenExe, 'claude');
    expect(seenArgs, ['-p', 'DISTILL_PROMPT']);
    expect(seenCwd, isNull);
    expect(r.rawOutput, contains('domainNotes'));
    expect(r.exitCode, 0);
    expect(r.ok, isTrue);
  });

  test('distill uses codex exec args when tool is codex', () async {
    List<String>? seenArgs;
    final runner = CliRunner(
      tool: 'codex',
      processRunner: (exe, args, {workingDirectory}) async {
        seenArgs = args;
        return const ProcessResultLite(0, '{}', '');
      },
    );
    await runner.distill(prompt: 'D');
    expect(seenArgs, ['exec', 'D']);
  });

  test('distill surfaces non-zero exit in RunnerResult', () async {
    final runner = CliRunner(
      tool: 'claude',
      processRunner: (exe, args, {workingDirectory}) async =>
          const ProcessResultLite(2, '', 'fail'),
    );
    final r = await runner.distill(prompt: 'P');
    expect(r.ok, isFalse);
    expect(r.exitCode, 2);
  });
}
