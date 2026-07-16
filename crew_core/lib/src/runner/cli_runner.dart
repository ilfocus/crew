import 'dart:io';
import '../models/agent_template.dart';
import 'runner.dart';

class ProcessResultLite {
  final int exitCode;
  final String stdout;
  final String stderr;
  const ProcessResultLite(this.exitCode, this.stdout, this.stderr);
}

typedef ProcessRunner = Future<ProcessResultLite> Function(
  String executable,
  List<String> args, {
  String? workingDirectory,
});

Future<ProcessResultLite> _defaultProcessRunner(
  String executable,
  List<String> args, {
  String? workingDirectory,
}) async {
  final r = await Process.run(executable, args,
      workingDirectory: workingDirectory);
  return ProcessResultLite(r.exitCode, r.stdout.toString(), r.stderr.toString());
}

class CliRunner implements Runner {
  final String tool; // 'claude' | 'codex'
  final ProcessRunner _run;

  CliRunner({this.tool = 'claude', ProcessRunner? processRunner})
      : _run = processRunner ?? _defaultProcessRunner;

  List<String> _args(String prompt) {
    switch (tool) {
      case 'codex':
        return ['exec', prompt];
      case 'claude':
      default:
        return ['-p', prompt];
    }
  }

  @override
  Future<RunnerResult> probe({
    required String workingDir,
    required String prompt,
    required AgentTemplate template,
  }) async {
    final res = await _run(tool, _args(prompt), workingDirectory: workingDir);
    return RunnerResult(res.stdout, res.exitCode);
  }

  @override
  Future<RunnerResult> distill({required String prompt}) async {
    final res = await _run(tool, _args(prompt));
    return RunnerResult(res.stdout, res.exitCode);
  }
}
