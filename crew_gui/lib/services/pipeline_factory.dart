// crew_gui/lib/services/pipeline_factory.dart
import 'package:crew_core/crew_core.dart';

List<OutputAdapter> adaptersFor(Set<String> targets) {
  final adapters = <OutputAdapter>[MemoryAdapter(), DocsAdapter(), McpAdapter()];
  if (targets.contains('claude')) adapters.add(ClaudeAdapter());
  if (targets.contains('codex')) adapters.add(CodexAdapter());
  return adapters;
}

GenerationPipeline buildPipeline(
  CrewConfig config, {
  required AgentTemplate? Function(String ref) resolve,
  Runner? runner,
}) {
  return GenerationPipeline(
    runner: runner ?? _runnerFor(config),
    adapters: adaptersFor(config.targets.toSet()),
    resolve: resolve,
  );
}

Runner _runnerFor(CrewConfig config) {
  switch (config.runner) {
    case 'cli':
      return CliRunner(tool: config.cliTool);
    case 'api':
      throw UnsupportedError('ApiRunner 尚未实现（runner: api）');
    default:
      throw UnsupportedError('未知 runner：${config.runner}');
  }
}
