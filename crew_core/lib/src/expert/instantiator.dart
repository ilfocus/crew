// crew_core/lib/src/expert/instantiator.dart
import '../models/agent_core.dart';
import '../models/agent_spec.dart';
import '../models/domain_expertise.dart';
import '../models/expert.dart' show MemoryEntry, ProjectRef;
import '../models/file_artifact.dart';

class InstantiatedAgent {
  final AgentSpec spec;
  final List<FileArtifact> memorySeed;
  const InstantiatedAgent(this.spec, this.memorySeed);
}

/// 把「某 agent 的某个领域专长」实例化进新 workspace（spec §6 instantiate）。
///
/// 输入：
/// - [core]：agent 本体身份（personality/principles/role/tools）
/// - [domain]：该 agent 在某个领域的 L2 专长（notes/playbooks/projects 索引）
/// - [agentName]：workspace 侧 agent 名（spec.name）
/// - [newRepos]：新 workspace 的仓库路径（spec.repos）
///
/// 输出：
/// - spec：由 core + newRepos 组装；不带任何 L1 specifics
///   （keyFiles/coordinates/moduleStructure/dataflow/techStack/sdks/difficulties 全空）
/// - memorySeed：位于 `memory/<agentName>/` 下，全部 `isMemory:true`
///   - `MEMORY.md`：索引（默认模板）
///   - `domain-notes.md`：domain.notes（L2）
///   - `playbooks/<basename>`：domain.playbooks 每一项
///   - `projects.md`：domain.projects 只读引用列表
///   - `TOOLS.md`（可选，仅 core.tools 非空时）：core.tools 清单
///
/// **绝不带**：任何 project 的 L1（solved/keyFiles/coordinates）——避免误套 + 泄漏。
InstantiatedAgent instantiate({
  required AgentCore core,
  required DomainExpertise domain,
  required String agentName,
  required List<String> newRepos,
}) {
  final spec = AgentSpec(
    name: agentName,
    displayName: core.displayName,
    repos: newRepos,
    role: core.role,
    coordinates: '',
    moduleStructure: '',
    keyFiles: const [],
    dataflow: '',
    memoryConvention: '',
    conventions: const [],
    personality: core.personality,
    principles: core.principles,
    // techStack/sdks/difficulties 是 L1 specifics，instance 时不带
    techStack: const [],
    sdks: const [],
    difficulties: const [],
    source: 'private', // 实例化时新 workspace 来源未知，默认私有
    github: '',
  );

  final memDir = 'memory/$agentName';
  final seed = <FileArtifact>[];

  // MEMORY.md — 索引（默认模板）
  seed.add(FileArtifact(
    '$memDir/MEMORY.md',
    _defaultMemoryIndex(core, domain, agentName),
    isMemory: true,
  ));

  // domain-notes.md
  seed.add(FileArtifact(
    '$memDir/domain-notes.md',
    domain.notes,
    isMemory: true,
  ));

  // playbooks/<basename>
  for (final pb in domain.playbooks) {
    final base = _basename(pb.path);
    seed.add(FileArtifact(
      '$memDir/playbooks/$base',
      pb.content,
      isMemory: true,
    ));
  }

  // projects.md — 只读引用
  seed.add(FileArtifact(
    '$memDir/projects.md',
    _renderProjectsMd(domain.projects),
    isMemory: true,
  ));

  // TOOLS.md（可选，仅 core.tools 非空时）
  if (core.tools.isNotEmpty) {
    seed.add(FileArtifact(
      '$memDir/TOOLS.md',
      _renderToolsMd(core.tools),
      isMemory: true,
    ));
  }

  return InstantiatedAgent(spec, seed);
}

String _defaultMemoryIndex(AgentCore core, DomainExpertise domain, String agentName) {
  final display = core.displayName.isNotEmpty ? core.displayName : core.name;
  final sb = StringBuffer()
    ..writeln('# MEMORY — $agentName')
    ..writeln()
    ..writeln('此 agent 由 `${display}`（id: `${core.id}`，role: `${core.role}`）'
        '在领域 `${domain.domain.isEmpty ? '(未指定)' : domain.domain}` 上实例化而来。')
    ..writeln()
    ..writeln('## 文件结构')
    ..writeln('- `MEMORY.md`         —— 本索引')
    ..writeln('- `domain-notes.md`   —— 跨项目抽象出的领域笔记（L2）')
    ..writeln('- `playbooks/`        —— 通用排查 / 操作 playbook（L2）')
    ..writeln('- `projects.md`       —— 已学习过的项目列表（只读参考）');
    if (core.tools.isNotEmpty) {
      sb.writeln('- `TOOLS.md`          —— 可用工具清单');
    }
    sb
    ..writeln()
    ..writeln('> 注：本 agent 不携带任何 L1 项目特定信息（solved/keyFiles/coordinates）。');
  return sb.toString();
}

String _basename(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? path : path.substring(i + 1);
}

String _renderProjectsMd(List<ProjectRef> projects) {
  final sb = StringBuffer()
    ..writeln('# 已学习项目（只读参考）')
    ..writeln()
    ..writeln('> 这些是当前领域专家从以下项目中蒸馏而来；仅供查阅，不应在此 agent 中修改。')
    ..writeln();
  if (projects.isEmpty) {
    sb.writeln('（暂无）');
    return sb.toString();
  }
  sb.writeln('| Project ID | Summary |');
  sb.writeln('| --- | --- |');
  for (final p in projects) {
    sb.writeln('| ${p.id} | ${p.summary} |');
  }
  return sb.toString();
}

String _renderToolsMd(List<String> tools) {
  final sb = StringBuffer()
    ..writeln('# 可用工具清单')
    ..writeln()
    ..writeln('> 此 agent 实例化时携带的工具（skill / mcp）引用列表。')
    ..writeln();
  for (final t in tools) {
    sb.writeln('- $t');
  }
  return sb.toString();
}
