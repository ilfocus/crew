// crew_core/lib/src/expert/expert_pool_adapter.dart
import 'dart:convert';
import '../models/expert.dart';
import '../models/file_artifact.dart';

/// Renders an [Expert] into a list of [FileArtifact]s suitable for writing
/// to disk via [WritePlanner].
///
/// Layout (relative to the expert's directory):
/// - expert.json              (isMemory: false)
/// - IDENTITY.md              (isMemory: false)
/// - COMPETENCE.md            (isMemory: false)
/// - memory/MEMORY.md         (isMemory: true)
/// - memory/solved/<path>     (isMemory: true) — one per MemoryEntry, or README.md template
/// - memory/playbooks/<path>  (isMemory: true) — one per MemoryEntry, or README.md template
/// - memory/project-notes.md  (isMemory: true) — project experts only
/// - memory/domain-notes.md   (isMemory: true) — domain experts only
/// - memory/projects.md       (isMemory: true) — domain experts only
class ExpertPoolAdapter {
  const ExpertPoolAdapter();

  List<FileArtifact> render(Expert expert) {
    final artifacts = <FileArtifact>[
      FileArtifact(
        'expert.json',
        const JsonEncoder.withIndent('  ').convert(expert.toJson()),
      ),
      FileArtifact('IDENTITY.md', _renderIdentity(expert)),
      FileArtifact('COMPETENCE.md', _renderCompetence(expert)),
      FileArtifact('memory/MEMORY.md', expert.memory.index, isMemory: true),
    ];

    // Solved entries
    if (expert.memory.solved.isEmpty) {
      artifacts.add(const FileArtifact(
        'memory/solved/README.md',
        _solvedTemplate,
        isMemory: true,
      ));
    } else {
      for (final e in expert.memory.solved) {
        final name = _stripPrefix(e.path, 'solved/');
        artifacts.add(FileArtifact(
          'memory/solved/$name',
          e.content,
          isMemory: true,
        ));
      }
    }

    // Playbook entries
    if (expert.memory.playbooks.isEmpty) {
      artifacts.add(const FileArtifact(
        'memory/playbooks/README.md',
        _playbooksTemplate,
        isMemory: true,
      ));
    } else {
      for (final e in expert.memory.playbooks) {
        final name = _stripPrefix(e.path, 'playbooks/');
        artifacts.add(FileArtifact(
          'memory/playbooks/$name',
          e.content,
          isMemory: true,
        ));
      }
    }

    // Kind-specific notes
    if (expert.kind == ExpertKind.project) {
      artifacts.add(FileArtifact(
        'memory/project-notes.md',
        expert.memory.notes,
        isMemory: true,
      ));
    } else {
      artifacts.add(FileArtifact(
        'memory/domain-notes.md',
        expert.memory.notes,
        isMemory: true,
      ));
      artifacts.add(FileArtifact(
        'memory/projects.md',
        _renderProjects(expert),
        isMemory: true,
      ));
    }

    return artifacts;
  }

  /// Strip a leading directory prefix from [path] so that a MemoryEntry
  /// stored as `solved/foo.md` renders to `memory/solved/foo.md` rather than
  /// `memory/solved/solved/foo.md`. A bare `foo.md` is returned unchanged.
  static String _stripPrefix(String path, String prefix) {
    if (path.startsWith(prefix)) return path.substring(prefix.length);
    return path;
  }

  static String _renderIdentity(Expert e) {
    final buf = StringBuffer('# ${e.spec.displayName}\n\n');
    buf.writeln('## Role\n');
    buf.writeln(e.spec.role.isEmpty ? '_(not specified)_' : e.spec.role);
    buf.writeln();
    buf.writeln('## Personality\n');
    buf.writeln(
        e.spec.personality.isEmpty ? '_(not specified)_' : e.spec.personality);
    buf.writeln();
    buf.writeln('## Principles\n');
    if (e.spec.principles.isEmpty) {
      buf.writeln('_(none)_');
    } else {
      for (final p in e.spec.principles) {
        buf.writeln('- $p');
      }
    }
    return buf.toString();
  }

  static String _renderCompetence(Expert e) {
    final buf = StringBuffer('# Competence — ${e.spec.displayName}\n\n');
    buf.writeln('## Tech Stack\n');
    if (e.spec.techStack.isEmpty) {
      buf.writeln('_(none specified)_');
    } else {
      for (final t in e.spec.techStack) {
        buf.writeln('- $t');
      }
    }
    buf.writeln();
    buf.writeln('## SDKs\n');
    if (e.spec.sdks.isEmpty) {
      buf.writeln('_(none specified)_');
    } else {
      for (final s in e.spec.sdks) {
        buf.writeln('- $s');
      }
    }
    buf.writeln();
    buf.writeln('## Difficulties\n');
    if (e.spec.difficulties.isEmpty) {
      buf.writeln('_(none specified)_');
    } else {
      for (final d in e.spec.difficulties) {
        buf.writeln('- $d');
      }
    }
    buf.writeln();
    buf.writeln('## Coordinates\n');
    buf.writeln(
        e.spec.coordinates.isEmpty ? '_(not specified)_' : e.spec.coordinates);
    buf.writeln();
    buf.writeln('## Module Structure\n');
    buf.writeln(e.spec.moduleStructure.isEmpty
        ? '_(not specified)_'
        : e.spec.moduleStructure);
    buf.writeln();
    buf.writeln('## Key Files\n');
    if (e.spec.keyFiles.isEmpty) {
      buf.writeln('_(none)_');
    } else {
      for (final k in e.spec.keyFiles) {
        buf.writeln('- `${k.path}` — ${k.purpose}');
      }
    }
    buf.writeln();
    buf.writeln('## GitHub\n');
    buf.writeln(e.spec.github.isEmpty ? '_(not specified)_' : e.spec.github);
    return buf.toString();
  }

  static String _renderProjects(Expert e) {
    final buf = StringBuffer('# Projects\n\n');
    if (e.memory.projects.isEmpty) {
      buf.writeln('_(no linked projects)_');
      return buf.toString();
    }
    for (final p in e.memory.projects) {
      buf.writeln('- **${p.id}** — ${p.summary}');
    }
    return buf.toString();
  }

  static const _solvedTemplate = '''# Solved

This directory holds records of solved issues and their resolutions.

Add one markdown file per solved problem. The expert pool will preserve
files you create here across regenerations.
''';

  static const _playbooksTemplate = '''# Playbooks

This directory holds playbooks — reusable procedures for recurring tasks.

Add one markdown file per playbook. The expert pool will preserve files
you create here across regenerations.
''';
}
