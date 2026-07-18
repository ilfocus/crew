// crew_cli/lib/src/commands/publish.dart
import 'dart:io';

import 'package:crew_core/crew_core.dart';

class PublishOptions {
  /// Pool-side agent id (个体代号，spec §2.1)。
  final String agentId;
  final String agentName;
  final String workspacePath;
  final String retention; // full | experience-only | none
  final String source; // opensource | private
  final String? domain; // --to <domain>，可选
  final Directory poolDir;
  final String cliTool;
  final int version;

  const PublishOptions({
    required this.agentId,
    required this.agentName,
    required this.workspacePath,
    required this.retention,
    required this.source,
    required this.poolDir,
    this.domain,
    this.cliTool = 'claude',
    this.version = 1,
  });
}

class PublishResult {
  final String? agentId;
  final String? projectId;
  final String? poolPath;
  final String? domainMerged;

  const PublishResult({
    this.agentId,
    this.projectId,
    this.poolPath,
    this.domainMerged,
  });
}

/// 把 workspace 中某 agent 的发布结果落到 [AgentPool]。
///
/// 流程（spec §6 管线① publish）：
/// 1. 读 workspace agent（spec + memory）
/// 2. 探测 git remote（用于 projectId + opensource 时回填 github）
/// 3. 调 [publishProject] 把 AgentSpec+memory 分流为 AgentCore + ProjectCompetence
/// 4. 把 AgentProfile（core + 已有 memory 或空 memory + meta）落到池
/// 5. 把 ProjectCompetence 落到 `agents/<agentId>/projects/<projectId>/`
/// 6. 若指定 `--to <domain>`：
///    - 载入或创建空壳 DomainExpertise
///    - 调 [mergeIntoDomain] 蒸馏并入（多对多 + 反向索引）
///    - 回写更新后的 domain 与 project（含反向索引）
Future<PublishResult> runPublish({
  required PublishOptions options,
  Runner? runner, // inject for testing; defaults to CliRunner(tool: options.cliTool)
}) async {
  // 1. Read workspace agent
  final reader = WorkspaceReader(Directory(options.workspacePath));
  final agent = await reader.readAgent(options.agentName);
  if (agent == null) {
    throw ArgumentError(
        'Agent "${options.agentName}" not found in ${options.workspacePath}');
  }

  // 2. Probe git remote
  final gitUrl = RepoAnalyzer().gitRemoteUrl(options.workspacePath);

  // 3. Publish (new API: returns PublishOutcome{core, project} or null)
  final outcome = publishProject(
    agentId: options.agentId,
    spec: agent.spec,
    workspaceMemory: agent.memory,
    retention: options.retention,
    source: options.source,
    gitRemoteUrl: gitUrl,
    workspacePath: options.workspacePath,
    version: options.version,
  );

  if (outcome == null) {
    // retention == 'none'
    return const PublishResult();
  }

  final pool = AgentPool(options.poolDir);

  // 4. Save agent profile — core + memory + meta
  // 若池中已有该 agent，保留其既有 memory（不覆盖用户编辑的短期/长期记忆）
  final existing = await pool.load(options.agentId);
  final memory = existing?.memory ?? const AgentMemory();
  final profile = AgentProfile(
    core: outcome.core,
    memory: memory,
    meta: AgentMeta(version: options.version),
  );
  await pool.save(profile);

  // 5. Save the project (L1) — 保留既有 domains 反向索引（多对多场景下不能被覆盖）
  final existingProject =
      await pool.loadProject(options.agentId, outcome.project.projectId);
  final preservedDomains = <String>{
    ...outcome.project.domains,
    ...?existingProject?.domains ?? const <String>[],
  }.toList();
  final projectJson = outcome.project.toJson()
    ..['domains'] = preservedDomains;
  final project = ProjectCompetence.fromJson(projectJson);
  await pool.saveProject(options.agentId, project);

  // 6. Optional domain merge
  String? domainMerged;
  if (options.domain != null && options.domain!.isNotEmpty) {
    final actualRunner = runner ?? CliRunner(tool: options.cliTool);
    var domain = await pool.loadDomain(options.agentId, options.domain!);
    if (domain == null) {
      // 创建空壳 domain（仅含 domain 名，其余由 merge 填充）
      domain = DomainExpertise(domain: options.domain!);
    }
    final merged = await mergeIntoDomain(
      domain: domain,
      project: project,
      runner: actualRunner,
    );
    await pool.saveDomain(options.agentId, merged.domain);
    // 回写反向索引已更新的 project
    await pool.saveProject(options.agentId, merged.project);
    domainMerged = options.domain;
  }

  return PublishResult(
    agentId: options.agentId,
    projectId: outcome.project.projectId,
    poolPath:
        '${options.poolDir.path}/agents/${options.agentId}/projects/${outcome.project.projectId}',
    domainMerged: domainMerged,
  );
}
