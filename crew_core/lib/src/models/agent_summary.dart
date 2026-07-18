// crew_core/lib/src/models/agent_summary.dart

/// 池侧 [AgentProfile] 的轻量摘要，用于列表展示（spec §3 `pool.yaml`）。
class AgentSummary {
  /// 个体 id（`AgentCore.id`）。
  final String id;

  final String displayName;

  /// 该 agent 掌握的领域清单（`domains/<d>/`）。
  final List<String> domains;

  /// 该 agent 干过的项目数。
  final int projectCount;

  final int version;

  const AgentSummary({
    required this.id,
    required this.displayName,
    required this.domains,
    required this.projectCount,
    required this.version,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentSummary &&
          id == other.id &&
          displayName == other.displayName &&
          version == other.version;

  @override
  int get hashCode => Object.hash(id, displayName, version);

  @override
  String toString() => 'AgentSummary($id, v$version, '
      'domains=${domains.length}, projects=$projectCount)';
}
