// crew_gui/lib/models/project_entry.dart
class ProjectEntry {
  final String name;
  final String path;
  final String createdAt;
  final int repoCount;
  final int agentCount;
  const ProjectEntry({
    required this.name,
    required this.path,
    required this.createdAt,
    required this.repoCount,
    required this.agentCount,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'createdAt': createdAt,
        'repoCount': repoCount,
        'agentCount': agentCount,
      };

  factory ProjectEntry.fromJson(Map<String, dynamic> j) => ProjectEntry(
        name: j['name'] as String,
        path: j['path'] as String,
        createdAt: j['createdAt'] as String,
        repoCount: j['repoCount'] as int,
        agentCount: j['agentCount'] as int,
      );
}
