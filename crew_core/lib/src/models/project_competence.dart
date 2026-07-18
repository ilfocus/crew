// crew_core/lib/src/models/project_competence.dart
import 'agent_spec.dart' show KeyFile;
import 'expert.dart' show MemoryEntry;

/// 4-项目能力（L1，绑定项目），spec §4.3 / §5。
///
/// 挂在 Agent 之下，表示"实际接了该项目"才有的内容：
/// - 项目坐标 / 模块结构 / 关键文件:行 / SDK / 重难点（来自 AgentSpec 的迁移字段）
/// - L1 记忆：notes（语义）/ solved（情景）/ playbooks（项目专属程序）
/// - `domains`：反向索引——该项目归属哪些领域（**多对多**，spec §2.2）
class ProjectCompetence {
  final String projectId;
  final List<String> repos;
  final String coordinates;
  final String moduleStructure;
  final List<KeyFile> keyFiles;
  final String dataflow;
  final List<String> techStack;
  final List<String> sdks;
  final List<String> difficulties;
  final String github;
  final String source; // opensource | private
  final String retention; // full | experience-only

  // L1 记忆
  final String notes; // project-notes.md
  final List<MemoryEntry> solved; // memory/solved/<*>
  final List<MemoryEntry> playbooks; // memory/playbooks/<*>

  /// 反向索引：该项目被并入哪些 domain（多对多）。
  final List<String> domains;

  const ProjectCompetence({
    required this.projectId,
    this.repos = const [],
    this.coordinates = '',
    this.moduleStructure = '',
    this.keyFiles = const [],
    this.dataflow = '',
    this.techStack = const [],
    this.sdks = const [],
    this.difficulties = const [],
    this.github = '',
    this.source = 'private',
    this.retention = 'full',
    this.notes = '',
    this.solved = const [],
    this.playbooks = const [],
    this.domains = const [],
  });

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'repos': repos,
        'coordinates': coordinates,
        'moduleStructure': moduleStructure,
        'keyFiles': keyFiles.map((e) => e.toJson()).toList(),
        'dataflow': dataflow,
        'techStack': techStack,
        'sdks': sdks,
        'difficulties': difficulties,
        'github': github,
        'source': source,
        'retention': retention,
        'notes': notes,
        'solved': solved.map((e) => e.toJson()).toList(),
        'playbooks': playbooks.map((e) => e.toJson()).toList(),
        'domains': domains,
      };

  factory ProjectCompetence.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(
      dynamic v,
      T Function(Map<String, dynamic>) fromJson,
    ) =>
        ((v as List?) ?? const [])
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList();
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return ProjectCompetence(
      projectId: j['projectId']?.toString() ?? '',
      repos: strList(j['repos']),
      coordinates: j['coordinates']?.toString() ?? '',
      moduleStructure: j['moduleStructure']?.toString() ?? '',
      keyFiles: list(j['keyFiles'], KeyFile.fromJson),
      dataflow: j['dataflow']?.toString() ?? '',
      techStack: strList(j['techStack']),
      sdks: strList(j['sdks']),
      difficulties: strList(j['difficulties']),
      github: j['github']?.toString() ?? '',
      source: j['source']?.toString() ?? 'private',
      retention: j['retention']?.toString() ?? 'full',
      notes: j['notes']?.toString() ?? '',
      solved: list(j['solved'], MemoryEntry.fromJson),
      playbooks: list(j['playbooks'], MemoryEntry.fromJson),
      domains: strList(j['domains']),
    );
  }
}
