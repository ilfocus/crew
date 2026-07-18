// crew_core/lib/src/models/domain_expertise.dart
import 'expert.dart' show MemoryEntry, ProjectRef;

/// 4-领域专长（L2，可迁移），spec §4.2 / §5。
///
/// 挂在 Agent 之下，表示"成为该领域专家"才有的内容：
/// - `notes`：领域经验/套路/判断标准正文（EXPERTISE.md）。
/// - `playbooks`：领域级程序记忆（L2，可迁移）。
/// - `projects`：该领域学过的项目索引（**多对多**：同一 project-id 可同时
///   被多个 domain 的 `projects` 引用，spec §2.2）。
class DomainExpertise {
  final String domain;

  /// `EXPERTISE.md` 正文：领域经验/重难点/常见坑/SDK 选型/架构套路。
  final String notes;

  /// 领域级判断标准（质量红线 / 品味）。
  final List<String> principles;

  /// `playbooks/<*>`：L2 可迁移程序记忆。
  final List<MemoryEntry> playbooks;

  /// `projects.md`：该领域学过的项目引用列表（多对多）。
  ///
  /// project 正文单一真源在 `projects/<project-id>/`，这里只是引用。
  final List<ProjectRef> projects;

  const DomainExpertise({
    required this.domain,
    this.notes = '',
    this.principles = const [],
    this.playbooks = const [],
    this.projects = const [],
  });

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'notes': notes,
        'principles': principles,
        'playbooks': playbooks.map((e) => e.toJson()).toList(),
        'projects': projects.map((e) => e.toJson()).toList(),
      };

  factory DomainExpertise.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(
      dynamic v,
      T Function(Map<String, dynamic>) fromJson,
    ) =>
        ((v as List?) ?? const [])
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList();
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return DomainExpertise(
      domain: j['domain']?.toString() ?? '',
      notes: j['notes']?.toString() ?? '',
      principles: strList(j['principles']),
      playbooks: list(j['playbooks'], MemoryEntry.fromJson),
      projects: list(j['projects'], ProjectRef.fromJson),
    );
  }
}
