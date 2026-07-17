// crew_gui/lib/services/workspace_browser.dart
import 'dart:convert';
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:path/path.dart' as p;
import '../ui/widgets/markdown_file_viewer.dart';

/// 浏览一个 workspace 目录下专家的 markdown 文件结构。
///
/// 工作区结构（每个 agent）：
/// - .claude/agents/<name>.md
/// - .codex/agents/<name>.toml
/// - .crew/specs/<name>.json
/// - memory/<name>/MEMORY.md
/// - memory/<name>/project-notes.md
/// - memory/<name>/solved/*.md
/// - memory/<name>/playbooks/*.md
class WorkspaceBrowser {
  final Directory root;
  WorkspaceBrowser(this.root);

  /// 列出 workspace 下所有 agent 的名字（来自 `.crew/specs/*.json`）。
  /// 若 specs 目录不存在，回退扫描 `.claude/agents/*.md`。
  List<String> listAgentNames() {
    final specsDir = Directory(p.join(root.path, '.crew', 'specs'));
    final names = <String>{};
    if (specsDir.existsSync()) {
      for (final e in specsDir.listSync()) {
        if (e is File && e.path.endsWith('.json')) {
          names.add(p.basenameWithoutExtension(e.path));
        }
      }
    }
    if (names.isEmpty) {
      final claudeDir = Directory(p.join(root.path, '.claude', 'agents'));
      if (claudeDir.existsSync()) {
        for (final e in claudeDir.listSync()) {
          if (e is File && e.path.endsWith('.md')) {
            names.add(p.basenameWithoutExtension(e.path));
          }
        }
      }
    }
    return names.toList()..sort();
  }

  /// 读取某个 agent 的 spec（用于显示角色/人格等）。文件不存在返回 null。
  AgentSpec? readSpec(String name) {
    final f = File(p.join(root.path, '.crew', 'specs', '$name.json'));
    if (!f.existsSync()) return null;
    try {
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      return AgentSpec.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 列出某个 agent 对应的所有 markdown/toml 文件清单（按分组组织）。
  /// 文件不存在的条目也会列出（绝对路径正确，读取时 viewer 会显示「文件不存在」）。
  List<MarkdownFileEntry> listAgentFiles(String name) {
    final entries = <MarkdownFileEntry>[];

    // Agent 配置
    final claudeAgent = File(p.join(root.path, '.claude', 'agents', '$name.md'));
    entries.add(MarkdownFileEntry(
      relativePath: '.claude/agents/$name.md',
      absolutePath: claudeAgent.path,
      label: '$name.md (claude)',
      group: 'Agent 配置',
    ));
    final codexAgent = File(p.join(root.path, '.codex', 'agents', '$name.toml'));
    if (codexAgent.existsSync()) {
      entries.add(MarkdownFileEntry(
        relativePath: '.codex/agents/$name.toml',
        absolutePath: codexAgent.path,
        label: '$name.toml (codex)',
        group: 'Agent 配置',
      ));
    }

    // 记忆文档
    final memDir = Directory(p.join(root.path, 'memory', name));
    void addMem(String rel, String label) {
      entries.add(MarkdownFileEntry(
        relativePath: rel,
        absolutePath: p.join(root.path, rel),
        label: label,
        group: '记忆',
      ));
    }

    addMem('memory/$name/MEMORY.md', 'MEMORY.md');
    addMem('memory/$name/project-notes.md', 'project-notes.md');

    // solved 与 playbooks 子目录：列出实际存在的文件
    for (final sub in const ['solved', 'playbooks']) {
      final dir = Directory(p.join(memDir.path, sub));
      if (!dir.existsSync()) continue;
      for (final e in dir.listSync()) {
        if (e is! File) continue;
        final base = p.basename(e.path);
        final rel = 'memory/$name/$sub/$base';
        entries.add(MarkdownFileEntry(
          relativePath: rel,
          absolutePath: e.path,
          label: '$sub/$base',
          group: '记忆',
        ));
      }
    }
    return entries;
  }
}

/// 浏览专家池中某个专家目录下的 markdown 文件。
///
/// 专家目录结构（由 ExpertPoolAdapter 生成）：
/// - expert.json
/// - IDENTITY.md
/// - COMPETENCE.md
/// - memory/MEMORY.md
/// - memory/solved/*.md
/// - memory/playbooks/*.md
/// - memory/project-notes.md (项目专家) / memory/domain-notes.md (领域专家)
/// - memory/projects.md (领域专家)
class ExpertPoolBrowser {
  final Directory expertDir;
  ExpertPoolBrowser(this.expertDir);

  /// 读取 expert.json。文件不存在返回 null。
  Expert? loadExpert() {
    final f = File(p.join(expertDir.path, 'expert.json'));
    if (!f.existsSync()) return null;
    try {
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      return Expert.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 列出该专家目录下所有 markdown 文件。
  List<MarkdownFileEntry> listFiles() {
    final entries = <MarkdownFileEntry>[];

    void addIfExists(String rel, String label, String group) {
      final f = File(p.join(expertDir.path, rel));
      if (f.existsSync()) {
        entries.add(MarkdownFileEntry(
          relativePath: rel,
          absolutePath: f.path,
          label: label,
          group: group,
        ));
      }
    }

    // 身份与能力
    addIfExists('IDENTITY.md', 'IDENTITY.md', '身份与能力');
    addIfExists('COMPETENCE.md', 'COMPETENCE.md', '身份与能力');

    // 记忆文档
    addIfExists('memory/MEMORY.md', 'MEMORY.md', '记忆');
    addIfExists('memory/project-notes.md', 'project-notes.md', '记忆');
    addIfExists('memory/domain-notes.md', 'domain-notes.md', '记忆');
    addIfExists('memory/projects.md', 'projects.md', '记忆');

    // solved 子目录
    final solvedDir = Directory(p.join(expertDir.path, 'memory', 'solved'));
    if (solvedDir.existsSync()) {
      for (final e in solvedDir.listSync()) {
        if (e is! File) continue;
        final base = p.basename(e.path);
        entries.add(MarkdownFileEntry(
          relativePath: 'memory/solved/$base',
          absolutePath: e.path,
          label: 'solved/$base',
          group: '记忆',
        ));
      }
    }

    // playbooks 子目录
    final playbooksDir =
        Directory(p.join(expertDir.path, 'memory', 'playbooks'));
    if (playbooksDir.existsSync()) {
      for (final e in playbooksDir.listSync()) {
        if (e is! File) continue;
        final base = p.basename(e.path);
        entries.add(MarkdownFileEntry(
          relativePath: 'memory/playbooks/$base',
          absolutePath: e.path,
          label: 'playbooks/$base',
          group: '记忆',
        ));
      }
    }
    return entries;
  }
}

