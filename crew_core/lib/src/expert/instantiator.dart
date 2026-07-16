// crew_core/lib/src/expert/instantiator.dart
import '../models/agent_spec.dart';
import '../models/expert.dart';
import '../models/file_artifact.dart';

class InstantiatedAgent {
  final AgentSpec spec;
  final List<FileArtifact> memorySeed;
  const InstantiatedAgent(this.spec, this.memorySeed);
}

/// 把领域专家 [domain] 实例化到一个新的 workspace 中。
///
/// 返回的 [InstantiatedAgent] 包含：
/// - spec：从 domain.spec copyWith(name=agentName, repos=newRepos)，
///   继承 personality/principles/techStack/sdks/difficulties 等可迁移字段
/// - memorySeed：一组 isMemory=true 的 FileArtifact，路径均位于
///   `memory/<agentName>/` 下：
///   - MEMORY.md          —— 索引（domain.memory.index 或默认模板）
///   - domain-notes.md    —— domain.memory.notes
///   - playbooks/<path>   —— domain.memory.playbooks 每一项
///   - projects.md        —— domain.memory.projects 只读列表
///   不包含 solved/ 条目（L1 specifics 不带过来）。
InstantiatedAgent instantiate({
  required Expert domain,
  required String agentName,
  required List<String> newRepos,
}) {
  final spec = domain.spec.copyWith(name: agentName, repos: newRepos);

  final memDir = 'memory/$agentName';
  final seed = <FileArtifact>[];

  // MEMORY.md — 索引
  final indexContent = domain.memory.index.isNotEmpty
      ? domain.memory.index
      : _defaultMemoryIndex(domain, agentName);
  seed.add(FileArtifact('$memDir/MEMORY.md', indexContent, isMemory: true));

  // domain-notes.md
  seed.add(FileArtifact(
    '$memDir/domain-notes.md',
    domain.memory.notes,
    isMemory: true,
  ));

  // playbooks/<path>
  for (final pb in domain.memory.playbooks) {
    // playbook.path 可能是 "排查-X.md" 或 "playbooks/X.md" 之类；统一放到
    // memory/<agentName>/playbooks/<basename> 下，避免重复前缀。
    final base = _basename(pb.path);
    seed.add(FileArtifact(
      '$memDir/playbooks/$base',
      pb.content,
      isMemory: true,
    ));
  }

  // projects.md — 只读列表
  seed.add(FileArtifact(
    '$memDir/projects.md',
    _renderProjectsMd(domain.memory.projects),
    isMemory: true,
  ));

  return InstantiatedAgent(spec, seed);
}

String _defaultMemoryIndex(Expert domain, String agentName) {
  final sb = StringBuffer()
    ..writeln('# MEMORY — $agentName')
    ..writeln()
    ..writeln('此 agent 由领域专家 `${domain.spec.displayName.isNotEmpty ? domain.spec.displayName : domain.spec.name}`'
        '（domain: ${domain.domain.isEmpty ? '(未指定)' : domain.domain}）实例化而来。')
    ..writeln()
    ..writeln('## 文件结构')
    ..writeln('- `MEMORY.md`         —— 本索引')
    ..writeln('- `domain-notes.md`   —— 跨项目抽象出的领域笔记（L2）')
    ..writeln('- `playbooks/`        —— 通用排查 / 操作 playbook')
    ..writeln('- `projects.md`       —— 已学习过的项目列表（只读参考）')
    ..writeln()
    ..writeln('> 注：本 agent 不携带任何 L1 项目特定信息（solved/ 等）。');
  return sb.toString();
}

String _basename(String path) {
  // 简化 basename：取最后一个 `/` 之后的部分；若无 `/` 则原样返回。
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
