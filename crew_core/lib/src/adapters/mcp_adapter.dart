import '../models/file_artifact.dart';
import '../models/generation_result.dart';
import 'output_adapter.dart';

class McpAdapter implements OutputAdapter {
  @override
  String get target => 'mcp';

  @override
  List<FileArtifact> render(GenerationResult result) {
    return const [
      FileArtifact('.mcp.json', '{\n  "mcpServers": {}\n}\n'),
      FileArtifact('.codex/config.toml', '# MCP servers for codex\n'),
    ];
  }
}
