// crew_core/lib/src/expert/agent_pool_adapter.dart
import 'dart:convert';

import '../models/agent_profile.dart';
import '../models/domain_expertise.dart';
import '../models/project_competence.dart';
import '../models/file_artifact.dart';

/// 把 [AgentProfile] 渲染成相对 `<poolRoot>/agents/<id>/` 的 [FileArtifact] 列表，
/// 对齐 spec §3 布局。
///
/// 布局：
/// - `agent.json`（isMemory=false）= core+memory+meta（单一事实源）
/// - `IDENTITY.md` / `RELATIONSHIPS.md` / `TOOLS.md`（isMemory=false，视图）
/// - `memory/MEMORY.md`、`memory/short-term.md`（isMemory=true）
/// - `memory/long-term/<path>`（isMemory=true；空时写 README.md 模板）
/// - 每个 domain：`domains/<d>/domain.json`(false) + `EXPERTISE.md`(false) +
///   `playbooks/<*>`(true，空 README) + `projects.md`(true)
/// - 每个 project：`projects/<pid>/project.json`(false) + `COMPETENCE.md`(false)
///   + `memory/project-notes.md`(true) + `memory/solved/<*>`(true，空 README)
///   + `memory/playbooks/<*>`(true，空 README)
class AgentPoolAdapter {
  const AgentPoolAdapter();

  List<FileArtifact> render(AgentProfile agent) {
    final out = <FileArtifact>[];

    // --- agent.json（事实源） ---
    out.add(FileArtifact(
      'agent.json',
      const JsonEncoder.withIndent('  ').convert(agent.toJson()),
    ));

    // --- 视图 ---
    out.add(FileArtifact('IDENTITY.md', _renderIdentity(agent)));
    out.add(FileArtifact('RELATIONSHIPS.md', _renderRelationships(agent)));
    out.add(FileArtifact('TOOLS.md', _renderTools(agent)));

    // --- agent 本体记忆 ---
    out.add(FileArtifact(
      'memory/MEMORY.md',
      agent.memory.index,
      isMemory: true,
    ));
    out.add(FileArtifact(
      'memory/short-term.md',
      agent.memory.shortTerm,
      isMemory: true,
    ));

    if (agent.memory.longTerm.isEmpty) {
      out.add(const FileArtifact(
        'memory/long-term/README.md',
        _longTermTemplate,
        isMemory: true,
      ));
    } else {
      for (final e in agent.memory.longTerm) {
        out.add(FileArtifact(
          'memory/long-term/${e.path}',
          e.content,
          isMemory: true,
        ));
      }
    }

    // --- domains ---
    for (final d in agent.domains) {
      out.addAll(renderDomain(d));
    }

    // --- projects ---
    for (final p in agent.projects) {
      out.addAll(renderProject(p));
    }

    return out;
  }

  // ─── 视图渲染 ─────────────────────────────────────────

  static String _renderIdentity(AgentProfile a) {
    final c = a.core;
    final buf = StringBuffer('# ${c.displayName}\n\n');
    buf.writeln('## Role\n');
    buf.writeln(c.role.isEmpty ? '_(not specified)_' : c.role);
    buf.writeln();
    buf.writeln('## Personality\n');
    buf.writeln(c.personality.isEmpty ? '_(not specified)_' : c.personality);
    buf.writeln();
    buf.writeln('## Principles\n');
    if (c.principles.isEmpty) {
      buf.writeln('_(none)_');
    } else {
      for (final p in c.principles) {
        buf.writeln('- $p');
      }
    }
    return buf.toString();
  }

  static String _renderRelationships(AgentProfile a) {
    final r = a.core.relationships;
    if (r.isEmpty) return '# Relationships\n\n_(not specified)_\n';
    // 已是自由 markdown，原样落盘
    return r.endsWith('\n') ? r : '$r\n';
  }

  static String _renderTools(AgentProfile a) {
    final buf = StringBuffer('# Tools\n\n');
    if (a.core.tools.isEmpty) {
      buf.writeln('_(none configured)_');
      return buf.toString();
    }
    buf.writeln('| Tool |');
    buf.writeln('| --- |');
    for (final t in a.core.tools) {
      buf.writeln('| $t |');
    }
    return buf.toString();
  }

  // ─── domain 渲染 ─────────────────────────────────────

  /// 渲染单个 [DomainExpertise] 的全部工件（`domains/<d>/**`）。
  /// 暴露为 public 以便细粒度 API（[AgentPool.saveDomain]）调用。
  List<FileArtifact> renderDomain(DomainExpertise d) {
    final out = <FileArtifact>[];
    out.add(FileArtifact(
      'domains/${d.domain}/domain.json',
      const JsonEncoder.withIndent('  ').convert(d.toJson()),
    ));
    out.add(FileArtifact(
      'domains/${d.domain}/EXPERTISE.md',
      _renderExpertise(d),
    ));

    if (d.playbooks.isEmpty) {
      out.add(FileArtifact(
        'domains/${d.domain}/playbooks/README.md',
        _playbooksTemplate,
        isMemory: true,
      ));
    } else {
      for (final e in d.playbooks) {
        final name = _stripPrefix(e.path, 'playbooks/');
        out.add(FileArtifact(
          'domains/${d.domain}/playbooks/$name',
          e.content,
          isMemory: true,
        ));
      }
    }

    out.add(FileArtifact(
      'domains/${d.domain}/projects.md',
      _renderProjectsRef(d),
      isMemory: true,
    ));
    return out;
  }

  static String _renderExpertise(DomainExpertise d) {
    final buf = StringBuffer('# Expertise — ${d.domain}\n\n');
    buf.writeln('## Notes\n');
    buf.writeln(d.notes.isEmpty ? '_(not specified)_' : d.notes);
    buf.writeln();
    buf.writeln('## Principles\n');
    if (d.principles.isEmpty) {
      buf.writeln('_(none)_');
    } else {
      for (final p in d.principles) {
        buf.writeln('- $p');
      }
    }
    return buf.toString();
  }

  static String _renderProjectsRef(DomainExpertise d) {
    final buf = StringBuffer('# Projects (domain: ${d.domain})\n\n');
    if (d.projects.isEmpty) {
      buf.writeln('_(no linked projects)_');
      return buf.toString();
    }
    for (final p in d.projects) {
      buf.writeln('- **${p.id}** — ${p.summary}');
    }
    return buf.toString();
  }

  // ─── project 渲染 ────────────────────────────────────

  /// 渲染单个 [ProjectCompetence] 的全部工件（`projects/<pid>/**`）。
  /// 暴露为 public 以便细粒度 API（[AgentPool.saveProject]）调用。
  List<FileArtifact> renderProject(ProjectCompetence p) {
    final out = <FileArtifact>[];
    out.add(FileArtifact(
      'projects/${p.projectId}/project.json',
      const JsonEncoder.withIndent('  ').convert(p.toJson()),
    ));
    out.add(FileArtifact(
      'projects/${p.projectId}/COMPETENCE.md',
      _renderCompetence(p),
    ));

    out.add(FileArtifact(
      'projects/${p.projectId}/memory/project-notes.md',
      p.notes,
      isMemory: true,
    ));

    if (p.solved.isEmpty) {
      out.add(FileArtifact(
        'projects/${p.projectId}/memory/solved/README.md',
        _solvedTemplate,
        isMemory: true,
      ));
    } else {
      for (final e in p.solved) {
        final name = _stripPrefix(e.path, 'solved/');
        out.add(FileArtifact(
          'projects/${p.projectId}/memory/solved/$name',
          e.content,
          isMemory: true,
        ));
      }
    }

    if (p.playbooks.isEmpty) {
      out.add(FileArtifact(
        'projects/${p.projectId}/memory/playbooks/README.md',
        _playbooksTemplate,
        isMemory: true,
      ));
    } else {
      for (final e in p.playbooks) {
        final name = _stripPrefix(e.path, 'playbooks/');
        out.add(FileArtifact(
          'projects/${p.projectId}/memory/playbooks/$name',
          e.content,
          isMemory: true,
        ));
      }
    }

    return out;
  }

  static String _renderCompetence(ProjectCompetence p) {
    final buf = StringBuffer('# Competence — ${p.projectId}\n\n');
    buf.writeln('## Tech Stack\n');
    if (p.techStack.isEmpty) {
      buf.writeln('_(none specified)_');
    } else {
      for (final t in p.techStack) {
        buf.writeln('- $t');
      }
    }
    buf.writeln();
    buf.writeln('## SDKs\n');
    if (p.sdks.isEmpty) {
      buf.writeln('_(none specified)_');
    } else {
      for (final s in p.sdks) {
        buf.writeln('- $s');
      }
    }
    buf.writeln();
    buf.writeln('## Difficulties\n');
    if (p.difficulties.isEmpty) {
      buf.writeln('_(none specified)_');
    } else {
      for (final d in p.difficulties) {
        buf.writeln('- $d');
      }
    }
    buf.writeln();
    buf.writeln('## Coordinates\n');
    buf.writeln(p.coordinates.isEmpty ? '_(not specified)_' : p.coordinates);
    buf.writeln();
    buf.writeln('## Module Structure\n');
    buf.writeln(
        p.moduleStructure.isEmpty ? '_(not specified)_' : p.moduleStructure);
    buf.writeln();
    buf.writeln('## Key Files\n');
    if (p.keyFiles.isEmpty) {
      buf.writeln('_(none)_');
    } else {
      for (final k in p.keyFiles) {
        buf.writeln('- `${k.path}` — ${k.purpose}');
      }
    }
    buf.writeln();
    buf.writeln('## Dataflow\n');
    buf.writeln(p.dataflow.isEmpty ? '_(not specified)_' : p.dataflow);
    buf.writeln();
    buf.writeln('## GitHub\n');
    buf.writeln(p.github.isEmpty ? '_(not specified)_' : p.github);
    buf.writeln();
    buf.writeln('## Domains\n');
    if (p.domains.isEmpty) {
      buf.writeln('_(none)_');
    } else {
      for (final d in p.domains) {
        buf.writeln('- $d');
      }
    }
    return buf.toString();
  }

  /// 去掉 path 前缀（避免 `solved/solved/x.md`）。
  static String _stripPrefix(String path, String prefix) {
    if (path.startsWith(prefix)) return path.substring(prefix.length);
    return path;
  }

  static const _solvedTemplate = '''# Solved

This directory holds records of solved issues and their resolutions.

Add one markdown file per solved problem. The pool preserves files you
create here across regenerations.
''';

  static const _playbooksTemplate = '''# Playbooks

This directory holds playbooks — reusable procedures for recurring tasks.

Add one markdown file per playbook. The pool preserves files you create
here across regenerations.
''';

  static const _longTermTemplate = '''# Long-term memory

This directory holds long-term memories — one file per entry.

Long-term entries are only appended, never auto-deleted. Use consolidation
(see spec §4.4) to promote short-term entries here on session close.
''';
}
