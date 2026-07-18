// crew_core/lib/src/expert/publisher.dart
import '../models/agent_core.dart';
import '../models/agent_spec.dart';
import '../models/expert.dart';
import '../models/project_competence.dart';
import 'project_id.dart';
import 'redact.dart';

/// 一次发布结果：把 workspace 的 AgentSpec + 记忆拆分为「某 agent 的一次项目发布」。
///
/// - [core]：agent 本体身份（upsert 用——新建时落它，已存在时不覆盖 personality）。
/// - [project]：本次发布的项目能力（retention=none 时整个返回 null）。
class PublishOutcome {
  final AgentCore core;
  final ProjectCompetence project;
  const PublishOutcome(this.core, this.project);
}

/// 把 workspace 中 probe 出的 [AgentSpec] + L1 [ExpertMemory]
/// 映射为「某 agent-id 的一次项目发布」。
///
/// 隐私门控由 [retention] 控制：
/// - `none`           → 返回 null，不发布
/// - `full`           → 完整 core + project（含 L1）
/// - `experience-only`→ 抹去 L1 specifics（keyFiles/coordinates/repos/solved），
///                      保留可迁移字段（personality/principles/techStack/sdks/difficulties）
///                      和已抽象的 playbooks（路径脱敏）
///
/// [source] = `opensource` 时把 [gitRemoteUrl] 写入 project.github；
/// `private` 时 github 留空，避免泄漏私有仓库地址。
///
/// projectId 由 [deriveProjectId] 计算（URL 优先，回退 path hash）。
///
/// 字段映射（spec §5）：
/// - `name/displayName/role/personality/principles` → [AgentCore]
/// - `repos/coordinates/moduleStructure/keyFiles/dataflow/techStack/sdks/
///    difficulties/github/source` → [ProjectCompetence]
/// - `workspaceMemory.notes/solved/playbooks` → [ProjectCompetence] 的 L1 记忆
PublishOutcome? publishProject({
  required String agentId,
  required AgentSpec spec,
  required ExpertMemory workspaceMemory,
  required String retention, // full | experience-only | none
  required String source, // opensource | private
  String? gitRemoteUrl,
  required String workspacePath,
  required int version,
}) {
  if (retention == 'none') return null;

  final projectId = deriveProjectId(
    gitRemoteUrl: gitRemoteUrl,
    path: workspacePath,
  );
  final github = (source == 'opensource') ? (gitRemoteUrl ?? '') : '';

  // core：来自 spec 的本体字段（agent 个体身份，跨 domain/project 不变）。
  // relationships/tools 在 publish 时无来源，留空——后续由用户/其它流程补全。
  final core = AgentCore(
    id: agentId,
    name: spec.name,
    displayName: spec.displayName,
    role: spec.role,
    personality: spec.personality,
    principles: spec.principles,
  );

  if (retention == 'experience-only') {
    // 抹去 L1 specifics：keyFiles/coordinates/repos/solved + notes 路径脱敏
    final project = ProjectCompetence(
      projectId: projectId,
      repos: const <String>[],
      coordinates: '',
      moduleStructure: spec.moduleStructure, // 抽象结构可迁移
      keyFiles: const <KeyFile>[],
      dataflow: spec.dataflow, // 数据流抽象可迁移
      techStack: spec.techStack,
      sdks: spec.sdks,
      difficulties: spec.difficulties,
      github: github,
      source: source,
      retention: retention,
      notes: redactPaths(workspaceMemory.notes),
      solved: const <MemoryEntry>[],
      playbooks: workspaceMemory.playbooks
          .map((p) => MemoryEntry(p.path, redactPaths(p.content)))
          .toList(),
      domains: const <String>[], // 由 mergeIntoDomain 填
    );
    return PublishOutcome(core, project);
  }

  // full retention — 完整保留 L1
  final project = ProjectCompetence(
    projectId: projectId,
    repos: spec.repos,
    coordinates: spec.coordinates,
    moduleStructure: spec.moduleStructure,
    keyFiles: spec.keyFiles,
    dataflow: spec.dataflow,
    techStack: spec.techStack,
    sdks: spec.sdks,
    difficulties: spec.difficulties,
    github: github,
    source: source,
    retention: retention,
    notes: workspaceMemory.notes,
    solved: workspaceMemory.solved,
    playbooks: workspaceMemory.playbooks,
    domains: const <String>[], // 由 mergeIntoDomain 填
  );
  return PublishOutcome(core, project);
}
