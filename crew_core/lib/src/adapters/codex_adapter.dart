// crew_core/lib/src/adapters/codex_adapter.dart
import '../models/file_artifact.dart';
import '../models/generation_result.dart';
import 'agent_body.dart';
import 'output_adapter.dart';

class CodexAdapter implements OutputAdapter {
  @override
  String get target => 'codex';

  @override
  List<FileArtifact> render(GenerationResult result) {
    return result.specs.map((s) {
      final body = renderAgentBody(s);
      final content = StringBuffer()
        ..writeln('name = "${s.name}"')
        ..writeln('description = ${_tomlString(s.role)}')
        ..writeln('developer_instructions = """')
        ..write(body)
        ..writeln('"""');
      return FileArtifact('.codex/agents/${s.name}.toml', content.toString());
    }).toList();
  }

  String _tomlString(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}
