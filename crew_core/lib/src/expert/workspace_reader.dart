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
/// - 优先：`.crew/specs/<name>.json`（spec）+ `memory/<name>/`（memory）
/// - 兜底：当 `.crew/specs/` 不存在或读不到任何 agent 时（早期生成的工作区），
///   从 `.claude/agents/*.md` 或 `.codex/agents/*.toml` 反推 agent 名单，
///   构造最小 spec（name=文件名，其余字段为默认空值）并读取 `memory/<name>/`。
///
/// memory 读取规则（两种路径相同）：
///   - `MEMORY.md`        → memory.index
///   - `project-notes.md` → memory.notes
///   - `solved/*`         → memory.solved（跳过 README.md）
///   - `playbooks/*`      → memory.playbooks（跳过 README.md）
///   - projects：workspace 中不存留，恒为空
class WorkspaceReader {
  final Directory root;
  WorkspaceReader(this.root);

  /// 读取 workspace 中所有 agents：合并 legacy 名单与 `.crew/specs/*.json`，
  /// 同名 agent 以 spec JSON 为准（字段更完整）。这样既能覆盖早期工作区
  /// （仅有 `.claude/agents/`、`.codex/agents/`），也能覆盖新工作区（有 specs/），
  /// 还能兼容 specs/ 只补了部分 agent 的混合情形。
  Future<List<WorkspaceAgent>> readAgents() async {
    final byName = <String, WorkspaceAgent>{};
    // 先放 legacy（最小 spec），再被 spec JSON 覆盖。
    for (final a in await _readAgentsLegacy()) {
      byName[a.spec.name] = a;
    }
    final specsDir = Directory(p.join(root.path, '.crew', 'specs'));
    if (specsDir.existsSync()) {
      for (final entity in specsDir.listSync()) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.json')) continue;
        final name = p.basenameWithoutExtension(entity.path);
        final agent = await readAgent(name);
        if (agent != null) byName[agent.spec.name] = agent;
      }
    }
    final result = byName.values.toList()
      ..sort((a, b) => a.spec.name.compareTo(b.spec.name));
    return result;
  }

  /// 按 name 读取单个 agent。
  /// spec 文件存在时按 JSON 解析；不存在时进入 legacy 兜底——
  /// 仅当 `.claude/agents/<name>.md`、`.codex/agents/<name>.toml` 或
  /// `memory/<name>/` 至少有一项存在时，才返回最小 spec + memory，否则返回 null。
  Future<WorkspaceAgent?> readAgent(String name) async {
    final specFile = File(p.join(root.path, '.crew', 'specs', '$name.json'));
    if (specFile.existsSync()) {
      final specJson =
          jsonDecode(specFile.readAsStringSync()) as Map<String, dynamic>;
      final spec = AgentSpec.fromJson(specJson);
      return WorkspaceAgent(spec, _readMemory(name));
    }
    return _readAgentLegacy(name);
  }

  /// Legacy 兜底：扫描 `.claude/agents/` 与 `.codex/agents/` 反推 agent 名单。
  Future<List<WorkspaceAgent>> _readAgentsLegacy() async {
    final names = <String>{};
    void scan(Directory dir) {
      if (!dir.existsSync()) return;
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final path = entity.path;
        if (!path.endsWith('.md') && !path.endsWith('.toml')) continue;
        names.add(p.basenameWithoutExtension(path));
      }
    }

    scan(Directory(p.join(root.path, '.claude', 'agents')));
    scan(Directory(p.join(root.path, '.codex', 'agents')));

    final result = <WorkspaceAgent>[];
    for (final name in names) {
      final agent = await _readAgentLegacy(name);
      if (agent != null) result.add(agent);
    }
    result.sort((a, b) => a.spec.name.compareTo(b.spec.name));
    return result;
  }

  /// Legacy 兜底：构造最小 spec（name=文件名，其余字段默认）+ memory。
  /// 仅当存在该 agent 的痕迹（agent 文件或 memory 目录）时返回，否则 null。
  Future<WorkspaceAgent?> _readAgentLegacy(String name) async {
    final claudeFile = File(p.join(root.path, '.claude', 'agents', '$name.md'));
    final codexFile = File(p.join(root.path, '.codex', 'agents', '$name.toml'));
    final memDir = Directory(p.join(root.path, 'memory', name));
    if (!claudeFile.existsSync() &&
        !codexFile.existsSync() &&
        !memDir.existsSync()) {
      return null;
    }
    final spec = AgentSpec(
      name: name,
      displayName: name,
      repos: const [],
      role: '',
      coordinates: '',
      moduleStructure: '',
      keyFiles: const [],
      dataflow: '',
      memoryConvention: '',
      conventions: const [],
    );
    return WorkspaceAgent(spec, _readMemory(name));
  }

  ExpertMemory _readMemory(String name) {
    final memDir = Directory(p.join(root.path, 'memory', name));
    return ExpertMemory(
      index: _readFileIfExists(File(p.join(memDir.path, 'MEMORY.md'))),
      notes: _readFileIfExists(File(p.join(memDir.path, 'project-notes.md'))),
      solved: _readMemoryEntries(memDir, 'solved'),
      playbooks: _readMemoryEntries(memDir, 'playbooks'),
      projects: const <ProjectRef>[],
    );
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
