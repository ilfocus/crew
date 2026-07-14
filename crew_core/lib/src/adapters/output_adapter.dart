// crew_core/lib/src/adapters/output_adapter.dart
import '../models/file_artifact.dart';
import '../models/generation_result.dart';

abstract class OutputAdapter {
  String get target;
  List<FileArtifact> render(GenerationResult result);
}
