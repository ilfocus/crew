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

/// 浏览专家池中某个 agent 目录下的 markdown 文件。
///
/// Agent 目录结构（由 AgentPoolAdapter 生成，spec §3）：
/// - agent.json（事实源：core + memory + meta）
/// - IDENTITY.md / RELATIONSHIPS.md / TOOLS.md（视图）
/// - memory/MEMORY.md、memory/short-term.md、memory/long-term/*
/// - domains/<d>/domain.json + EXPERTISE.md + playbooks/* + projects.md
/// - projects/<p>/project.json + COMPETENCE.md + memory/project-notes.md +
///   memory/solved/* + memory/playbooks/*
class ExpertPoolBrowser {
  final Directory expertDir;
  ExpertPoolBrowser(this.expertDir);

  /// 读取 agent.json 解析为 [AgentProfile]。文件不存在返回 null。
  AgentProfile? loadAgent() {
    final f = File(p.join(expertDir.path, 'agent.json'));
    if (!f.existsSync()) return null;
    try {
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      return AgentProfile.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 列出该 agent 目录下所有 markdown 文件（按分组组织）。
  ///
  /// 扫描顺序：身份与能力 → 记忆 → 领域 → 项目。
  /// 文件不存在的条目会被跳过。
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

    void addDirIfExists(String rel, String labelPrefix, String group) {
      final dir = Directory(p.join(expertDir.path, rel));
      if (!dir.existsSync()) return;
      for (final e in dir.listSync()) {
        if (e is! File) continue;
        if (!e.path.endsWith('.md')) continue;
        final base = p.basename(e.path);
        entries.add(MarkdownFileEntry(
          relativePath: '$rel/$base',
          absolutePath: e.path,
          label: '$labelPrefix$base',
          group: group,
        ));
      }
    }

    // 身份与能力
    addIfExists('IDENTITY.md', 'IDENTITY.md', '身份与能力');
    addIfExists('RELATIONSHIPS.md', 'RELATIONSHIPS.md', '身份与能力');
    addIfExists('TOOLS.md', 'TOOLS.md', '身份与能力');

    // Agent 本体记忆
    addIfExists('memory/MEMORY.md', 'MEMORY.md', '记忆');
    addIfExists('memory/short-term.md', 'short-term.md', '记忆');
    addDirIfExists('memory/long-term', 'long-term/', '记忆');

    // 领域（每个 domain 一个子目录）
    final domainsDir = Directory(p.join(expertDir.path, 'domains'));
    if (domainsDir.existsSync()) {
      for (final d in domainsDir.listSync()) {
        if (d is! Directory) continue;
        final dname = p.basename(d.path);
        final group = '领域：$dname';
        addIfExists('domains/$dname/EXPERTISE.md', '$dname/EXPERTISE.md', group);
        addIfExists('domains/$dname/projects.md', '$dname/projects.md', group);
        addDirIfExists('domains/$dname/playbooks', '$dname/playbooks/', group);
      }
    }

    // 项目（每个 project 一个子目录；projectId 可能含斜杠 → 嵌套目录）
    final projectsDir = Directory(p.join(expertDir.path, 'projects'));
    if (projectsDir.existsSync()) {
      _scanProjects(projectsDir, projectsDir, entries);
    }

    return entries;
  }

  /// 递归扫描 projects/ 目录树，找所有含 project.json 的目录视作 project 根。
  /// projectId 是相对 projects/ 的相对路径（去掉前导 /）。
  void _scanProjects(
    Directory current,
    Directory projectsRoot,
    List<MarkdownFileEntry> entries,
  ) {
    final projectJson = File(p.join(current.path, 'project.json'));
    if (projectJson.existsSync()) {
      final rel = p.relative(current.path, from: projectsRoot.path);
      final group = '项目：$rel';
      _addProjectFiles(rel, group, entries);
      // project 的子目录里可能还有 nested projects（极少见），继续扫描
    }
    for (final e in current.listSync()) {
      if (e is Directory) _scanProjects(e, projectsRoot, entries);
    }
  }

  void _addProjectFiles(
    String rel,
    String group,
    List<MarkdownFileEntry> entries,
  ) {
    void addIfExists(String subRel, String label) {
      final f = File(p.join(expertDir.path, 'projects', rel, subRel));
      if (!f.existsSync()) return;
      entries.add(MarkdownFileEntry(
        relativePath: 'projects/$rel/$subRel',
        absolutePath: f.path,
        label: label,
        group: group,
      ));
    }

    void addDirIfExists(String subRel, String labelPrefix) {
      final dir = Directory(p.join(expertDir.path, 'projects', rel, subRel));
      if (!dir.existsSync()) return;
      for (final e in dir.listSync()) {
        if (e is! File) continue;
        if (!e.path.endsWith('.md')) continue;
        final base = p.basename(e.path);
        entries.add(MarkdownFileEntry(
          relativePath: 'projects/$rel/$subRel/$base',
          absolutePath: e.path,
          label: '$labelPrefix$base',
          group: group,
        ));
      }
    }

    addIfExists('COMPETENCE.md', '$rel/COMPETENCE.md');
    addIfExists('memory/project-notes.md', '$rel/project-notes.md');
    addDirIfExists('memory/solved', '$rel/solved/');
    addDirIfExists('memory/playbooks', '$rel/playbooks/');
  }
}

