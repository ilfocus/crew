// crew_core/lib/src/expert/migrate.dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/agent_core.dart' show AgentCore, AgentMeta;
import '../models/agent_memory.dart';
import '../models/agent_profile.dart';
import '../models/domain_expertise.dart';
import '../models/expert.dart' show Expert, ExpertKind, ProjectRef;
import '../models/project_competence.dart';
import 'agent_pool.dart';

/// 迁移结果：本次 migrate 跑完后给上层看的报告。
class MigrationReport {
  /// 迁移出的 agent 数量（按 spec.name 聚类后）。
  final int agents;

  /// 搬入新布局的 domain 数量。
  final int domainsMoved;

  /// 搬入新布局的 project 数量。
  final int projectsMoved;

  /// 无法自动归属/有冲突、需要人工 review 的条目说明。
  final List<String> needsManualReview;

  const MigrationReport({
    required this.agents,
    required this.domainsMoved,
    required this.projectsMoved,
    required this.needsManualReview,
  });

  @override
  String toString() =>
      'MigrationReport(agents=$agents, domainsMoved=$domainsMoved, '
      'projectsMoved=$projectsMoved, needsManualReview=${needsManualReview.length})';
}

/// 把旧平铺布局（`<oldRoot>/{projects|domains}/<id>/expert.json`）
/// 迁移到新 agent 层级布局（`<newRoot>/agents/<agent-id>/...`）。
///
/// **聚类规则**（spec §2.1）：由 `spec.name` 聚类为"同一个体"，
/// `agentId = slug(name)`（即 name 本身）。同一 name 下的 project/domain
/// 全部归到同一 agent 下。
///
/// **冲突检测**：同一 cluster 内若有多条非空且互不相同的 `personality`，
/// 视为冲突——canonical 仍取首个非空 personality，但其余 personality 列入
/// [MigrationReport.needsManualReview] 供人工 review。
///
/// **字段映射**：
/// - 旧 ProjectExpert → [ProjectCompetence]（spec 字段 + L1 记忆按 D1 反向映射）
/// - 旧 DomainExpert → [DomainExpertise]（notes/playbooks 搬入；
///   `meta.learnedProjectIds` → `projects` 引用列表）
/// - canonical spec 的 personality/role/displayName/principles → [AgentCore]
/// - `relationships`/`tools`/`shortTerm` 无旧数据 → 空模板
///
/// **幂等**：`*.json` 是事实源会被覆盖（内容相同）；`isMemory:true` 的记忆
/// 文件已存在则 skip（由 [WritePlanner] 处理）。可重复运行不产生重复条目。
///
/// **由调用方负责备份旧数据**（`<root>` → `<root>.bak`）。
Future<MigrationReport> migratePool({
  required Directory oldRoot,
  required Directory newRoot,
  required int version,
}) async {
  // 1. 扫描旧 expert.json
  final oldProjects = <Expert>[];
  final oldDomains = <Expert>[];
  if (oldRoot.existsSync()) {
    oldProjects.addAll(await _scanKind(oldRoot, 'projects'));
    oldDomains.addAll(await _scanKind(oldRoot, 'domains'));
  }

  // 2. 按 spec.name 聚类
  final clusters = <String, _Cluster>{};
  for (final e in [...oldProjects, ...oldDomains]) {
    final name = e.spec.name;
    if (name.isEmpty) continue;
    final c = clusters.putIfAbsent(name, () => _Cluster(name: name));
    c.experts.add(e);
  }

  // 3. 对每个 cluster 处理
  final pool = AgentPool(newRoot);
  var domainsMoved = 0;
  var projectsMoved = 0;
  final needsManualReview = <String>[];

  for (final cluster in clusters.values) {
    // 检测 personality 冲突（多个非空且互不相同）
    final personalities = cluster.experts
        .map((e) => e.spec.personality)
        .where((s) => s.isNotEmpty)
        .toSet();
    if (personalities.length > 1) {
      needsManualReview.add(
          'agent "${cluster.name}": personality 冲突 ${personalities.toList()}');
    }

    // canonical spec：取第一个有非空 personality 的；否则取第一个
    final canonical = cluster.experts.firstWhere(
      (e) => e.spec.personality.isNotEmpty,
      orElse: () => cluster.experts.first,
    );

    final core = AgentCore(
      id: cluster.name,
      name: canonical.spec.name,
      displayName: canonical.spec.displayName,
      role: canonical.spec.role,
      personality: canonical.spec.personality,
      principles: canonical.spec.principles,
    );

    final profile = AgentProfile(
      core: core,
      memory: const AgentMemory(),
      meta: AgentMeta(version: version),
    );
    await pool.save(profile);

    // 该 cluster 内所有 domain 名（用于 project 反向索引）
    final domainNames = cluster.experts
        .where((x) => x.kind == ExpertKind.domain)
        .map((x) => x.domain)
        .where((s) => s.isNotEmpty)
        .toSet();

    // 4. 写入 ProjectCompetence（含 domains 反向索引）
    for (final e
        in cluster.experts.where((x) => x.kind == ExpertKind.project)) {
      final projectId = e.meta.projectId;
      if (projectId.isEmpty) continue;
      final project = ProjectCompetence(
        projectId: projectId,
        repos: e.spec.repos,
        coordinates: e.spec.coordinates,
        moduleStructure: e.spec.moduleStructure,
        keyFiles: e.spec.keyFiles,
        dataflow: e.spec.dataflow,
        techStack: e.spec.techStack,
        sdks: e.spec.sdks,
        difficulties: e.spec.difficulties,
        github: e.meta.github.isNotEmpty ? e.meta.github : e.spec.github,
        source: e.meta.source,
        retention: e.meta.retention,
        notes: e.memory.notes,
        solved: e.memory.solved,
        playbooks: e.memory.playbooks,
        domains: domainNames.toList(),
      );
      await pool.saveProject(cluster.name, project);
      projectsMoved++;
    }

    // 5. 写入 DomainExpertise（projects 引用列表）
    for (final e in cluster.experts.where((x) => x.kind == ExpertKind.domain)) {
      final refs = <ProjectRef>[];
      final learnedIds = e.meta.learnedProjectIds;
      if (learnedIds.isNotEmpty) {
        // learnedProjectIds 优先；summary 默认 = id（用户可后续编辑）
        for (final id in learnedIds) {
          refs.add(ProjectRef(id, id));
        }
      } else {
        refs.addAll(e.memory.projects);
      }

      final domain = DomainExpertise(
        domain: e.domain,
        notes: e.memory.notes,
        principles: e.spec.principles,
        playbooks: e.memory.playbooks,
        projects: refs,
      );
      await pool.saveDomain(cluster.name, domain);
      domainsMoved++;
    }
  }

  return MigrationReport(
    agents: clusters.length,
    domainsMoved: domainsMoved,
    projectsMoved: projectsMoved,
    needsManualReview: needsManualReview,
  );
}

class _Cluster {
  final String name;
  final List<Expert> experts = [];
  _Cluster({required this.name});
}

Future<List<Expert>> _scanKind(Directory root, String kindDir) async {
  final dir = Directory(p.join(root.path, kindDir));
  if (!dir.existsSync()) return const [];
  final out = <Expert>[];
  await for (final entry in dir.list(recursive: true)) {
    if (entry is! File) continue;
    if (p.basename(entry.path) != 'expert.json') continue;
    try {
      final raw = entry.readAsStringSync();
      final j = jsonDecode(raw) as Map<String, dynamic>;
      out.add(Expert.fromJson(j));
    } catch (_) {
      // skip malformed
    }
  }
  return out;
}
