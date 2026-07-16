// crew_cli/lib/src/commands/publish.dart
import 'dart:io';

import 'package:crew_core/crew_core.dart';

class PublishOptions {
  final String agentName;
  final String workspacePath;
  final String retention; // full | experience-only | none
  final String source; // opensource | private
  final String? domain;
  final Directory poolDir;
  final String cliTool;
  final int version;

  const PublishOptions({
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
  final String? projectId;
  final String? poolPath;
  final String? domainMerged;

  const PublishResult({
    this.projectId,
    this.poolPath,
    this.domainMerged,
  });
}

/// Core publish logic — testable with injected deps.
///
/// Flow:
/// 1. Read workspace agent (spec + memory) via [WorkspaceReader].
/// 2. Probe git remote for the workspace via [RepoAnalyzer].
/// 3. Publish via [publishProject] (returns null when retention == 'none').
/// 4. Save the resulting project expert to the pool.
/// 5. Optionally merge into a domain expert (creating it if absent).
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

  // 3. Publish
  final expert = publishProject(
    spec: agent.spec,
    workspaceMemory: agent.memory,
    retention: options.retention,
    source: options.source,
    gitRemoteUrl: gitUrl,
    workspacePath: options.workspacePath,
    version: options.version,
  );

  if (expert == null) {
    // retention == 'none'
    return const PublishResult();
  }

  // 4. Save to pool
  final pool = ExpertPool(options.poolDir);
  await pool.saveProject(expert);

  // 5. Optional domain merge
  String? domainMerged;
  if (options.domain != null && options.domain!.isNotEmpty) {
    final actualRunner = runner ?? CliRunner(tool: options.cliTool);
    var domain = await pool.loadDomain(options.domain!);
    if (domain == null) {
      // Create empty domain expert seeded from the workspace agent's spec.
      domain = Expert(
        kind: ExpertKind.domain,
        domain: options.domain!,
        spec: agent.spec.copyWith(
          name: options.domain!,
          displayName: options.domain!,
        ),
        memory: const ExpertMemory(),
        meta: ExpertMeta(
          source: options.source,
          retention: 'experience-only',
          version: options.version,
        ),
      );
    }
    final merged = await mergeIntoDomain(
      domain: domain,
      project: expert,
      runner: actualRunner,
      version: options.version,
    );
    await pool.saveDomain(merged);
    domainMerged = options.domain;
  }

  return PublishResult(
    projectId: expert.meta.projectId,
    poolPath:
        '${options.poolDir.path}/projects/${expert.meta.projectId}',
    domainMerged: domainMerged,
  );
}
