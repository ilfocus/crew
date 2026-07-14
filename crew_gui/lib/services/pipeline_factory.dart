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
    runner: runner ?? CliRunner(tool: 'claude'),
    adapters: adaptersFor(config.targets.toSet()),
  );
}
