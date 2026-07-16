// crew_core/lib/src/expert/workspace_reader.dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/agent_spec.dart';
import '../models/expert.dart';

/// workspace 中读取回的一个 agent：spec + 反向重建的 memory。
class WorkspaceAgent {
  final AgentSpec spec;
  final ExpertMemory memory;
  const WorkspaceAgent(this.spec, this.memory);
}

/// 从 workspace 目录反向读回 agents。
///
/// 读取规则：
/// - spec：`.crew/specs/<name>.json`
/// - memory：`memory/<name>/` 目录
///   - `MEMORY.md`        → memory.index
///   - `project-notes.md` → memory.notes
///   - `solved/*`         → memory.solved（跳过 README.md）
///   - `playbooks/*`      → memory.playbooks（跳过 README.md）
///   - projects：workspace 中不存留，恒为空
class WorkspaceReader {
  final Directory root;
  WorkspaceReader(this.root);

  /// 读取 workspace 中所有 agents：扫描 `.crew/specs/*.json`，
  /// 对每个文件调用 [readAgent]（name = 去掉 `.json` 后缀的文件名）。
  /// 过滤掉读取失败的（返回 null）。
  Future<List<WorkspaceAgent>> readAgents() async {
    final specsDir = Directory(p.join(root.path, '.crew', 'specs'));
    if (!specsDir.existsSync()) return const <WorkspaceAgent>[];
    final result = <WorkspaceAgent>[];
    for (final entity in specsDir.listSync()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.json')) continue;
      final name = p.basenameWithoutExtension(entity.path);
      final agent = await readAgent(name);
      if (agent != null) result.add(agent);
    }
    return result;
  }

  /// 按 name 读取单个 agent。spec 文件不存在时返回 null。
  Future<WorkspaceAgent?> readAgent(String name) async {
    final specFile = File(p.join(root.path, '.crew', 'specs', '$name.json'));
    if (!specFile.existsSync()) return null;
    final specJson =
        jsonDecode(specFile.readAsStringSync()) as Map<String, dynamic>;
    final spec = AgentSpec.fromJson(specJson);

    final memDir = Directory(p.join(root.path, 'memory', name));
    final index = _readFileIfExists(File(p.join(memDir.path, 'MEMORY.md')));
    final notes =
        _readFileIfExists(File(p.join(memDir.path, 'project-notes.md')));
    final solved = _readMemoryEntries(memDir, 'solved');
    final playbooks = _readMemoryEntries(memDir, 'playbooks');

    final memory = ExpertMemory(
      index: index,
      notes: notes,
      solved: solved,
      playbooks: playbooks,
      projects: const <ProjectRef>[],
    );
    return WorkspaceAgent(spec, memory);
  }

  String _readFileIfExists(File f) {
    if (!f.existsSync()) return '';
    return f.readAsStringSync();
  }

  /// 读取 `memory/<name>/<sub>/` 下所有文件（跳过 README.md），
  /// 每个文件成为 [MemoryEntry]（path = basename，content = 文件内容）。
  /// 目录不存在或为空时返回空列表。
  List<MemoryEntry> _readMemoryEntries(Directory memDir, String sub) {
    final dir = Directory(p.join(memDir.path, sub));
    if (!dir.existsSync()) return const <MemoryEntry>[];
    final entries = <MemoryEntry>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final base = p.basename(entity.path);
      if (base == 'README.md') continue;
      entries.add(MemoryEntry(base, entity.readAsStringSync()));
    }
    return entries;
  }
}
