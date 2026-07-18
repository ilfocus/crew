// crew_core/lib/src/models/agent_profile.dart
import 'agent_core.dart' show AgentCore, AgentMeta;
import 'agent_memory.dart' show AgentMemory;
import 'domain_expertise.dart' show DomainExpertise;
import 'project_competence.dart' show ProjectCompetence;

/// 池侧 Agent 聚合模型（spec §5）：一个「有自我的个体」+ 其掌握的领域 +
/// 干过的项目。
///
/// 注：spec 里把这个聚合叫 `Agent`，但 `models/agent.dart` 已被 workspace
/// 侧 `CrewConfig.agents` 条目占用（20+ 处使用），为避免冲突这里命名为
/// `AgentProfile`。语义不变：一个 agent 个体在池中的完整档案。
///
/// `agent.json` 仅覆盖 `core` + `memory` + `meta`（self 的单一事实源）；
/// `domains` / `projects` 各自独立落盘（见 Phase B/C）。
class AgentProfile {
  final AgentCore core;
  final AgentMemory memory;
  final AgentMeta meta;

  /// 该 agent 掌握的领域专长（L2，可多个）。`toJson` 不写它们。
  final List<DomainExpertise> domains;

  /// 该 agent 干过的项目（L1，可多个）。`toJson` 不写它们。
  final List<ProjectCompetence> projects;

  const AgentProfile({
    required this.core,
    this.memory = const AgentMemory(),
    this.meta = const AgentMeta(),
    this.domains = const [],
    this.projects = const [],
  });

  /// `agent.json` 内容：仅 core+memory+meta。
  Map<String, dynamic> toJson() => {
        'core': core.toJson(),
        'memory': memory.toJson(),
        'meta': meta.toJson(),
      };

  factory AgentProfile.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> asMap(dynamic v) =>
        Map<String, dynamic>.from(v as Map);
    return AgentProfile(
      core: AgentCore.fromJson(asMap(j['core'])),
      memory: j['memory'] != null
          ? AgentMemory.fromJson(asMap(j['memory']))
          : const AgentMemory(),
      meta: j['meta'] != null
          ? AgentMeta.fromJson(asMap(j['meta']))
          : const AgentMeta(),
      // domains/projects 不在 agent.json 里；由 AgentPool 单独读取组装
      domains: const [],
      projects: const [],
    );
  }

  /// 加入或替换一个 [ProjectCompetence]：按 `projectId` 去重，已存在则覆盖。
  AgentProfile withProject(ProjectCompetence p) {
    final list = <ProjectCompetence>[];
    var replaced = false;
    for (final existing in projects) {
      if (existing.projectId == p.projectId) {
        list.add(p);
        replaced = true;
      } else {
        list.add(existing);
      }
    }
    if (!replaced) list.add(p);
    return AgentProfile(
      core: core,
      memory: memory,
      meta: meta,
      domains: domains,
      projects: list,
    );
  }

  /// 加入或替换一个 [DomainExpertise]：按 `domain` 去重，已存在则覆盖。
  AgentProfile withDomain(DomainExpertise d) {
    final list = <DomainExpertise>[];
    var replaced = false;
    for (final existing in domains) {
      if (existing.domain == d.domain) {
        list.add(d);
        replaced = true;
      } else {
        list.add(existing);
      }
    }
    if (!replaced) list.add(d);
    return AgentProfile(
      core: core,
      memory: memory,
      meta: meta,
      domains: list,
      projects: projects,
    );
  }
}
