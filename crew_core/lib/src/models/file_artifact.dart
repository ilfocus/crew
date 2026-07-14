// crew_core/lib/src/models/file_artifact.dart
class FileArtifact {
  final String relativePath;
  final String content;
  final bool isMemory;
  const FileArtifact(this.relativePath, this.content, {this.isMemory = false});
}
