// crew_core/lib/src/expert/publisher.dart
import '../models/agent_spec.dart';
import '../models/expert.dart';
import 'project_id.dart';

/// 把 workspace 中 probe 出的 [AgentSpec] + L1 [ExpertMemory]
/// 发布成一个 [Expert]（kind = project）。
///
/// 隐私门控由 [retention] 控制：
/// - `none`           → 返回 null，不发布
/// - `full`           → 完整 spec + memory
/// - `experience-only`→ 抹去 L1 specific 信息（keyFiles/coordinates/repos/solved），
///                       只保留可迁移的 personality/principles/techStack/sdks/difficulties
///                       以及已经抽象的 playbooks
///
/// [source] = `opensource` 时把 [gitRemoteUrl] 写入 meta.github；
/// `private` 时 meta.github 留空，避免泄漏私有仓库地址。
///
/// projectId 由 [deriveProjectId] 计算（URL 优先，回退 path hash）。
Expert? publishProject({
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

  if (retention == 'experience-only') {
    // 抹去 L1 specifics：路径/坐标/仓库/已解决案例
    final redactedSpec = spec.copyWith(
      keyFiles: const <KeyFile>[],
      coordinates: '',
      repos: const <String>[],
    );
    final redactedMemory = ExpertMemory(
      index: workspaceMemory.index,
      notes: workspaceMemory.notes,
      solved: const <MemoryEntry>[], // L1 specifics removed
      playbooks: workspaceMemory.playbooks, // already abstract
      projects: const <ProjectRef>[],
    );
    return Expert(
      kind: ExpertKind.project,
      spec: redactedSpec,
      memory: redactedMemory,
      meta: ExpertMeta(
        source: source,
        github: github,
        retention: retention,
        projectId: projectId,
        version: version,
      ),
    );
  }

  // full retention — 完整保留
  return Expert(
    kind: ExpertKind.project,
    spec: spec,
    memory: workspaceMemory,
    meta: ExpertMeta(
      source: source,
      github: github,
      retention: retention,
      projectId: projectId,
      version: version,
    ),
  );
}
