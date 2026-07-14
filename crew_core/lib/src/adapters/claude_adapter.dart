// crew_core/lib/src/adapters/claude_adapter.dart
import '../models/file_artifact.dart';
import '../models/generation_result.dart';
import 'agent_body.dart';
import 'output_adapter.dart';

class ClaudeAdapter implements OutputAdapter {
  @override
  String get target => 'claude';

  @override
  List<FileArtifact> render(GenerationResult result) {
    return result.specs.map((s) {
      final content = StringBuffer()
        ..writeln('---')
        ..writeln('name: ${s.name}')
        ..writeln('description: ${s.role}')
        ..writeln('---')
        ..writeln()
        ..write(renderAgentBody(s));
      return FileArtifact('.claude/agents/${s.name}.md', content.toString());
    }).toList();
  }
}
