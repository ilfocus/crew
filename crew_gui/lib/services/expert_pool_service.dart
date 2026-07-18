// crew_gui/lib/services/expert_pool_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:path/path.dart' as p;

class PublishOutcome {
  final String? agentId;
  final String? projectId;
  final String? poolPath;
  final String? domainMerged;
  final String? error;
  bool get isSuccess => error == null;
  const PublishOutcome({
    this.agentId,
    this.projectId,
    this.poolPath,
    this.domainMerged,
    this.error,
  });
}

class UseExpertOutcome {
  final List<String> writtenPaths;
  final String? error;
  bool get isSuccess => error == null;
  const UseExpertOutcome({this.writtenPaths = const [], this.error});
}

class MigrateOutcome {
  final int agents;
  final int domainsMoved;
  final int projectsMoved;
  final List<String> needsManualReview;
  final String? backupPath;
  final String? error;
  bool get isSuccess => error == null;
  const MigrateOutcome({
    this.agents = 0,
    this.domainsMoved = 0,
    this.projectsMoved = 0,
    this.needsManualReview = const [],
    this.backupPath,
    this.error,
  });
}

/// GUI 侧专家池服务，封装 AgentPool 操作 + publish/use/migrate 管线。
///
/// 设计：纯函数调用 crew_core 原语（publishProject / mergeIntoDomain / instantiate /
/// migratePool），不依赖 crew_cli。HOME 探测仅发生在 [defaultForTool]。
class ExpertPoolService {
  final AgentPool pool;
  final Runner Function() runnerFactory;

  ExpertPoolService(this.pool, {required this.runnerFactory});

  /// Default factory: resolves ~/.crew/experts from HOME
  static ExpertPoolService defaultForTool(String cliTool) {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final poolDir = Directory('$home/.crew/experts');
    return ExpertPoolService(
      AgentPool(poolDir),
      runnerFactory: () => CliRunner(tool: cliTool),
    );
  }

  Future<List<AgentSummary>> list() => pool.list();

  /// 删除整个 agent（含其下所有 domains + projects + 记忆）。
  Future<void> deleteAgent(String agentId) => pool.delete(agentId);

  /// 删除某 agent 下的某个 domain（`agents/<agentId>/domains/<domain>/`）。
  Future<void> deleteDomain(String agentId, String domain) async {
    final dir = Directory(
        p.join(pool.root.path, 'agents', agentId, 'domains', domain));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// 删除某 agent 下的某个 project（`agents/<agentId>/projects/<projectId>/`）。
  /// projectId 可能含斜杠（如 `github.com/foo/bar`），对应嵌套目录。
  Future<void> deleteProject(String agentId, String projectId) async {
    final dir = Directory(
        p.join(pool.root.path, 'agents', agentId, 'projects', projectId));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// 把 workspace 中的 agent 发布到池（spec §6 publish）。
  ///
  /// 流程：readAgent → publishProject（分流 AgentCore + ProjectCompetence，
  /// 应用隐私策略）→ AgentPool.save/saveProject（保留既有 memory + domains
  /// 反向索引）→ 可选 mergeIntoDomain（多对多 + 回写反向索引）。
  Future<PublishOutcome> publish({
    required String agentId,
    required String workspacePath,
    required String agentName,
    required String retention,
    required String source,
    String? domain,
    required int version,
  }) async {
    try {
      final reader = WorkspaceReader(Directory(workspacePath));
      final agent = await reader.readAgent(agentName);
      if (agent == null) {
        return PublishOutcome(
            error: 'Agent "$agentName" not found in workspace');
      }

      final gitUrl = RepoAnalyzer().gitRemoteUrl(workspacePath);

      final outcome = publishProject(
        agentId: agentId,
        spec: agent.spec,
        workspaceMemory: agent.memory,
        retention: retention,
        source: source,
        gitRemoteUrl: gitUrl,
        workspacePath: workspacePath,
        version: version,
      );

      if (outcome == null) {
        return const PublishOutcome(); // retention=none
      }

      // Save agent profile — preserve existing memory（不覆盖用户编辑的短期/长期）
      final existing = await pool.load(agentId);
      final memory = existing?.memory ?? const AgentMemory();
      final profile = AgentProfile(
        core: outcome.core,
        memory: memory,
        meta: AgentMeta(version: version),
      );
      await pool.save(profile);

      // Save project — preserve existing domains reverse index（多对多场景）
      final existingProject =
          await pool.loadProject(agentId, outcome.project.projectId);
      final preservedDomains = <String>{
        ...outcome.project.domains,
        ...?existingProject?.domains ?? const <String>[],
      }.toList();
      final projectJson = outcome.project.toJson()
        ..['domains'] = preservedDomains;
      final project = ProjectCompetence.fromJson(projectJson);
      await pool.saveProject(agentId, project);

      String? domainMerged;
      if (domain != null && domain.isNotEmpty) {
        var domainExpertise = await pool.loadDomain(agentId, domain);
        domainExpertise ??= DomainExpertise(domain: domain);
        final merged = await mergeIntoDomain(
          domain: domainExpertise,
          project: project,
          runner: runnerFactory(),
        );
        await pool.saveDomain(agentId, merged.domain);
        // 回写反向索引已更新的 project
        await pool.saveProject(agentId, merged.project);
        domainMerged = domain;
      }

      return PublishOutcome(
        agentId: agentId,
        projectId: outcome.project.projectId,
        poolPath:
            '${pool.root.path}/agents/$agentId/projects/${outcome.project.projectId}',
        domainMerged: domainMerged,
      );
    } catch (e) {
      return PublishOutcome(error: e.toString());
    }
  }

  /// 实例化某 agent 的某领域专长到目标 workspace（spec §6 instantiate）。
  ///
  /// 流程：AgentPool.load(agentId) → loadDomain → instantiate → 写 memory seed
  /// （isMemory 已存在则 skip）+ spec json。绝不带 L1 specifics。
  Future<UseExpertOutcome> useExpert({
    required String agentId,
    required String domain,
    required String intoPath,
    required String agentName,
    required List<String> repos,
  }) async {
    try {
      final profile = await pool.load(agentId);
      if (profile == null) {
        return UseExpertOutcome(error: 'Agent "$agentId" not found in pool');
      }

      final domainExpertise = await pool.loadDomain(agentId, domain);
      if (domainExpertise == null) {
        return UseExpertOutcome(
            error: 'Domain "$domain" not found for agent "$agentId"');
      }

      final instantiated = instantiate(
        core: profile.core,
        domain: domainExpertise,
        agentName: agentName,
        newRepos: repos,
      );

      final writtenPaths = <String>[];
      final targetDir = Directory(intoPath);
      for (final artifact in instantiated.memorySeed) {
        final file = File('${targetDir.path}/${artifact.relativePath}');
        file.parent.createSync(recursive: true);
        if (artifact.isMemory && file.existsSync()) continue;
        file.writeAsStringSync(artifact.content);
        writtenPaths.add(artifact.relativePath);
      }

      // spec JSON
      final specFile = File('${targetDir.path}/.crew/specs/$agentName.json');
      specFile.parent.createSync(recursive: true);
      specFile.writeAsStringSync(jsonEncode(instantiated.spec.toJson()));
      writtenPaths.add('.crew/specs/$agentName.json');

      return UseExpertOutcome(writtenPaths: writtenPaths);
    } catch (e) {
      return UseExpertOutcome(error: e.toString());
    }
  }

  /// 一次性把旧平铺布局迁移到新 agent 层级布局。
  ///
  /// 流程：检测旧 `projects/` 或 `domains/` 子目录（在 root 或 .bak）→
  /// 首次运行备份 root → root.bak → migratePool(oldRoot=.bak, newRoot=root) →
  /// 删除 root 下的旧子目录。幂等（二次运行不重新备份）。
  Future<MigrateOutcome> migrate({required int version}) async {
    try {
      final root = pool.root;
      final bak = Directory('${root.path}.bak');

      final oldProjectsInRoot = Directory('${root.path}/projects');
      final oldDomainsInRoot = Directory('${root.path}/domains');
      final hasOldInRoot =
          oldProjectsInRoot.existsSync() || oldDomainsInRoot.existsSync();
      final hasOldInBak = bak.existsSync() &&
          (Directory('${bak.path}/projects').existsSync() ||
              Directory('${bak.path}/domains').existsSync());

      if (!hasOldInRoot && !hasOldInBak) {
        return const MigrateOutcome();
      }

      Directory oldRoot;
      String? backupPath;
      if (hasOldInBak) {
        oldRoot = bak;
      } else {
        await _copyDirectory(root, bak);
        backupPath = bak.path;
        oldRoot = bak;
      }

      final report = await migratePool(
        oldRoot: oldRoot,
        newRoot: root,
        version: version,
      );

      if (oldProjectsInRoot.existsSync()) {
        await oldProjectsInRoot.delete(recursive: true);
      }
      if (oldDomainsInRoot.existsSync()) {
        await oldDomainsInRoot.delete(recursive: true);
      }

      return MigrateOutcome(
        agents: report.agents,
        domainsMoved: report.domainsMoved,
        projectsMoved: report.projectsMoved,
        needsManualReview: report.needsManualReview,
        backupPath: backupPath,
      );
    } catch (e) {
      return MigrateOutcome(error: e.toString());
    }
  }
}

Future<void> _copyDirectory(Directory src, Directory dst) async {
  await dst.create(recursive: true);
  await for (final entry in src.list()) {
    final name = entry.path.split(RegExp(r'[/\\]')).last;
    if (entry is Directory) {
      await _copyDirectory(entry, Directory('${dst.path}/$name'));
    } else if (entry is File) {
      await entry.copy('${dst.path}/$name');
    }
  }
}
