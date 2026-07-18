// crew_core/lib/src/expert/agent_pool.dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../engine/write_planner.dart';
import '../models/agent_profile.dart';
import '../models/agent_summary.dart';
import '../models/domain_expertise.dart';
import '../models/project_competence.dart';
import 'agent_pool_adapter.dart';

/// File-system backed pool of agents.
///
/// 布局对齐 spec §3：
/// ```
/// <root>/
/// └── agents/<agent-id>/
///     ├── agent.json            # AgentProfile (core+memory+meta) 单一事实源
///     ├── IDENTITY.md / RELATIONSHIPS.md / TOOLS.md   # 视图
///     ├── memory/                # agent 本体记忆（isMemory=true）
///     ├── domains/<domain>/      # DomainExpertise（独立 domain.json + 视图 + 记忆）
///     └── projects/<project-id>/ # ProjectCompetence（独立 project.json + 视图 + L1 记忆）
///         # project-id 含 `/`（如 github.com/foo/bar）→ 嵌套目录
/// ```
///
/// 记忆保护：`save` 走 [WritePlanner]，`isMemory:true` 的已存在文件 skip。
/// 事实源是 `*.json`，记忆 md 文件是视图（用户编辑不会被覆盖）。
class AgentPool {
  final Directory root;
  final AgentPoolAdapter _adapter;
  final WritePlanner _planner;

  AgentPool(this.root, {AgentPoolAdapter? adapter, WritePlanner? planner})
      : _adapter = adapter ?? const AgentPoolAdapter(),
        _planner = planner ?? WritePlanner();

  Directory _agentDir(String agentId) =>
      Directory(p.join(root.path, 'agents', agentId));

  // ─── 整体存取 ──────────────────────────────────────────

  Future<void> save(AgentProfile agent) async {
    final dir = _agentDir(agent.core.id);
    final artifacts = _adapter.render(agent);
    final plan = _planner.plan(dir.path, artifacts);
    await _planner.apply(dir.path, plan);
  }

  Future<AgentProfile?> load(String agentId) async {
    final dir = _agentDir(agentId);
    final agentJson = File(p.join(dir.path, 'agent.json'));
    if (!agentJson.existsSync()) return null;
    final core = _parseJson(agentJson);
    if (core == null) return null;
    final profile = AgentProfile.fromJson(core);

    final domains = await _scanDomains(dir);
    final projects = await _scanProjects(dir);
    return AgentProfile(
      core: profile.core,
      memory: profile.memory,
      meta: profile.meta,
      domains: domains,
      projects: projects,
    );
  }

  Future<List<AgentSummary>> list() async {
    final agentsDir = Directory(p.join(root.path, 'agents'));
    if (!agentsDir.existsSync()) return const [];
    final out = <AgentSummary>[];
    for (final entry in agentsDir.listSync()) {
      if (entry is! Directory) continue;
      final agentJson = File(p.join(entry.path, 'agent.json'));
      if (!agentJson.existsSync()) continue;
      final j = _parseJson(agentJson);
      if (j == null) continue;
      final profile = AgentProfile.fromJson(j);
      final domains = await _scanDomains(entry);
      final projectCount = (await _scanProjects(entry)).length;
      out.add(AgentSummary(
        id: profile.core.id,
        displayName: profile.core.displayName,
        domains: domains.map((d) => d.domain).toList()..sort(),
        projectCount: projectCount,
        version: profile.meta.version,
      ));
    }
    return out;
  }

  Future<void> delete(String agentId) async {
    final dir = _agentDir(agentId);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  // ─── 细粒度 API ─────────────────────────────────────────

  Future<void> saveProject(String agentId, ProjectCompetence p) async {
    final dir = _agentDir(agentId);
    final artifacts = _adapter.renderProject(p);
    final plan = _planner.plan(dir.path, artifacts);
    await _planner.apply(dir.path, plan);
  }

  Future<void> saveDomain(String agentId, DomainExpertise d) async {
    final dir = _agentDir(agentId);
    final artifacts = _adapter.renderDomain(d);
    final plan = _planner.plan(dir.path, artifacts);
    await _planner.apply(dir.path, plan);
  }

  Future<ProjectCompetence?> loadProject(
      String agentId, String projectId) async {
    final f = File(p.join(_agentDir(agentId).path, 'projects', projectId, 'project.json'));
    final j = _parseJson(f);
    return j == null ? null : ProjectCompetence.fromJson(j);
  }

  Future<DomainExpertise?> loadDomain(String agentId, String domain) async {
    final f = File(p.join(_agentDir(agentId).path, 'domains', domain, 'domain.json'));
    final j = _parseJson(f);
    return j == null ? null : DomainExpertise.fromJson(j);
  }

  // ─── 扫描辅助 ──────────────────────────────────────────

  Future<List<DomainExpertise>> _scanDomains(Directory agentDir) async {
    final dir = Directory(p.join(agentDir.path, 'domains'));
    if (!dir.existsSync()) return const [];
    final out = <DomainExpertise>[];
    for (final entry in dir.listSync()) {
      if (entry is! Directory) continue;
      final f = File(p.join(entry.path, 'domain.json'));
      final j = _parseJson(f);
      if (j != null) out.add(DomainExpertise.fromJson(j));
    }
    return out;
  }

  Future<List<ProjectCompetence>> _scanProjects(Directory agentDir) async {
    final dir = Directory(p.join(agentDir.path, 'projects'));
    if (!dir.existsSync()) return const [];
    final out = <ProjectCompetence>[];
    await for (final entry in dir.list(recursive: true)) {
      if (entry is! File) continue;
      if (p.basename(entry.path) != 'project.json') continue;
      final j = _parseJson(entry);
      if (j != null) out.add(ProjectCompetence.fromJson(j));
    }
    return out;
  }

  Map<String, dynamic>? _parseJson(File f) {
    try {
      if (!f.existsSync()) return null;
      final raw = f.readAsStringSync();
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
