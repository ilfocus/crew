// crew_core/lib/src/adapters/memory_adapter.dart
import '../models/file_artifact.dart';
import '../models/generation_result.dart';
import 'output_adapter.dart';

class MemoryAdapter implements OutputAdapter {
  @override
  String get target => 'memory';

  @override
  List<FileArtifact> render(GenerationResult result) {
    final out = <FileArtifact>[];
    for (final s in result.specs) {
      final index = '# ${s.displayName} 的记忆索引\n\n'
          '开工前先读本文件及其指向的记忆；收工后把改动写成新记忆放入 '
          '`memory/${s.name}/` 并在此加一行指针。\n\n'
          '- [项目初始笔记](project-notes.md) — 角色与关联目录\n';
      final notes = '---\n'
          'name: project-notes\n'
          'description: ${s.displayName}（${s.role}）的初始项目笔记\n'
          '---\n\n'
          '角色：${s.role}\n'
          '关联目录：${s.repos.join('、')}\n';
      out.add(FileArtifact('memory/${s.name}/MEMORY.md', index, isMemory: true));
      out.add(FileArtifact('memory/${s.name}/project-notes.md', notes, isMemory: true));
    }
    return out;
  }
}
