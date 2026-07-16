// crew_core/lib/src/models/expert.dart
import 'agent_spec.dart';

enum ExpertKind { project, domain }

class MemoryEntry {
  final String path;
  final String content;
  const MemoryEntry(this.path, this.content);

  Map<String, dynamic> toJson() => {'path': path, 'content': content};

  factory MemoryEntry.fromJson(Map<String, dynamic> j) => MemoryEntry(
        j['path'].toString(),
        j['content']?.toString() ?? '',
      );
}

class ProjectRef {
  final String id;
  final String summary;
  const ProjectRef(this.id, this.summary);

  Map<String, dynamic> toJson() => {'id': id, 'summary': summary};

  factory ProjectRef.fromJson(Map<String, dynamic> j) => ProjectRef(
        j['id'].toString(),
        j['summary']?.toString() ?? '',
      );
}

class ExpertMemory {
  final String index; // MEMORY.md content
  final String notes; // project-notes (L1) or domain-notes (L2)
  final List<MemoryEntry> solved;
  final List<MemoryEntry> playbooks;
  final List<ProjectRef> projects; // only non-empty for domain

  const ExpertMemory({
    this.index = '',
    this.notes = '',
    this.solved = const [],
    this.playbooks = const [],
    this.projects = const [],
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'notes': notes,
        'solved': solved.map((e) => e.toJson()).toList(),
        'playbooks': playbooks.map((e) => e.toJson()).toList(),
        'projects': projects.map((e) => e.toJson()).toList(),
      };

  factory ExpertMemory.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(
      dynamic v,
      T Function(Map<String, dynamic>) fromJson,
    ) =>
        ((v as List?) ?? const [])
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList();
    return ExpertMemory(
      index: j['index']?.toString() ?? '',
      notes: j['notes']?.toString() ?? '',
      solved: list(j['solved'], MemoryEntry.fromJson),
      playbooks: list(j['playbooks'], MemoryEntry.fromJson),
      projects: list(j['projects'], ProjectRef.fromJson),
    );
  }
}

class ExpertMeta {
  final String source; // opensource | private
  final String github;
  final String retention; // full | experience-only | none
  final String projectId; // for project experts; empty for domain
  final int version;
  final List<String> learnedProjectIds; // for domain

  const ExpertMeta({
    this.source = 'private',
    this.github = '',
    this.retention = 'full',
    this.projectId = '',
    this.version = 1,
    this.learnedProjectIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'github': github,
        'retention': retention,
        'projectId': projectId,
        'version': version,
        'learnedProjectIds': learnedProjectIds,
      };

  factory ExpertMeta.fromJson(Map<String, dynamic> j) {
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return ExpertMeta(
      source: j['source']?.toString() ?? 'private',
      github: j['github']?.toString() ?? '',
      retention: j['retention']?.toString() ?? 'full',
      projectId: j['projectId']?.toString() ?? '',
      version: (j['version'] as num?)?.toInt() ?? 1,
      learnedProjectIds: strList(j['learnedProjectIds']),
    );
  }
}

class Expert {
  final ExpertKind kind;
  final String domain; // domain expert's domain name; empty for project
  final AgentSpec spec; // reuse existing AgentSpec
  final ExpertMemory memory;
  final ExpertMeta meta;

  const Expert({
    required this.kind,
    required this.spec,
    required this.memory,
    required this.meta,
    this.domain = '',
  });

  Map<String, dynamic> toJson() => {
        'kind': kind == ExpertKind.project ? 'project' : 'domain',
        'domain': domain,
        'spec': spec.toJson(),
        'memory': memory.toJson(),
        'meta': meta.toJson(),
      };

  factory Expert.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> asStringMap(dynamic v) =>
        Map<String, dynamic>.from(v as Map);
    return Expert(
      kind: j['kind']?.toString() == 'domain'
          ? ExpertKind.domain
          : ExpertKind.project,
      domain: j['domain']?.toString() ?? '',
      spec: AgentSpec.fromJson(asStringMap(j['spec'])),
      memory: ExpertMemory.fromJson(asStringMap(j['memory'])),
      meta: ExpertMeta.fromJson(asStringMap(j['meta'])),
    );
  }
}
