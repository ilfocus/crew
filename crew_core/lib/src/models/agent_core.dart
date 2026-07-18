// crew_core/lib/src/models/agent_core.dart

/// 池侧 Agent 本体的核心身份（spec §2.1 / §5）。
///
/// Agent 对标"一个有自我的个体"：`id` 是稳定唯一 slug（个体代号），
/// `role` 是可重复字段（多个 agent 同 role）。挂在本体的内容：
/// - 1 个性（personality / principles）
/// - 2 关系（relationships）
/// - 5 工具（tools）
///
/// 跨 domain / project 不变——只存一份，避免漂移。
class AgentCore {
  /// 稳定唯一 slug，人类可读（如 `ios-lin`、`quant-max`）。
  ///
  /// 由用户在创建/发布时指定；≠ role，避免按角色撞车。
  final String id;

  /// 机器名（= workspace agent name）。可与 id 不同。
  final String name;

  final String displayName;

  /// 角色，可重复；≠ id。
  final String role;

  /// 1 个性：说话/做事风格、价值观、判断品味。
  final String personality;

  /// 1 个性·判断标准 / 质量红线。
  final List<String> principles;

  /// 2 关系：自由 markdown（用户画像&喜好 + 协作 agent 名单&分工）。
  final String relationships;

  /// 5 工具：可用 skill / mcp 清单（id 列表）。
  final List<String> tools;

  const AgentCore({
    required this.id,
    required this.name,
    required this.displayName,
    required this.role,
    this.personality = '',
    this.principles = const [],
    this.relationships = '',
    this.tools = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'displayName': displayName,
        'role': role,
        'personality': personality,
        'principles': principles,
        'relationships': relationships,
        'tools': tools,
      };

  factory AgentCore.fromJson(Map<String, dynamic> j) {
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return AgentCore(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      displayName: j['displayName']?.toString() ?? '',
      role: j['role']?.toString() ?? '',
      personality: j['personality']?.toString() ?? '',
      principles: strList(j['principles']),
      relationships: j['relationships']?.toString() ?? '',
      tools: strList(j['tools']),
    );
  }
}

/// Agent 元数据（版本化等）。
class AgentMeta {
  final int version;

  const AgentMeta({this.version = 1});

  Map<String, dynamic> toJson() => {'version': version};

  factory AgentMeta.fromJson(Map<String, dynamic> j) => AgentMeta(
        version: (j['version'] as num?)?.toInt() ?? 1,
      );
}
