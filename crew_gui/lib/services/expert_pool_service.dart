// crew_gui/lib/services/expert_pool_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crew_core/crew_core.dart';

class PublishOutcome {
  final String? projectId;
  final String? poolPath;
  final String? domainMerged;
  final String? error;
  bool get isSuccess => error == null;
  const PublishOutcome({this.projectId, this.poolPath, this.domainMerged, this.error});
}

class UseExpertOutcome {
  final List<String> writtenPaths;
  final String? error;
  bool get isSuccess => error == null;
  const UseExpertOutcome({this.writtenPaths = const [], this.error});
}

class ExpertPoolService {
  final ExpertPool pool;
  final Runner Function() runnerFactory;

  ExpertPoolService(this.pool, {required this.runnerFactory});

  /// Default factory: resolves ~/.crew/experts from HOME
  static ExpertPoolService defaultForTool(String cliTool) {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final poolDir = Directory('$home/.crew/experts');
    return ExpertPoolService(
      ExpertPool(poolDir),
      runnerFactory: () => CliRunner(tool: cliTool),
    );
  }

  Future<List<ExpertSummary>> list() => pool.list();

  /// Recursively removes `projects/<projectId>/` from the pool. No-op if absent.
  Future<void> deleteProject(String projectId) =>
      pool.deleteProject(projectId);

  /// Recursively removes `domains/<domain>/` from the pool. No-op if absent.
  Future<void> deleteDomain(String domain) => pool.deleteDomain(domain);

  Future<PublishOutcome> publish({
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
        return PublishOutcome(error: 'Agent "$agentName" not found in workspace');
      }

      final gitUrl = RepoAnalyzer().gitRemoteUrl(workspacePath);

      final expert = publishProject(
        spec: agent.spec,
        workspaceMemory: agent.memory,
        retention: retention,
        source: source,
        gitRemoteUrl: gitUrl,
        workspacePath: workspacePath,
        version: version,
      );

      if (expert == null) {
        return const PublishOutcome(); // retention=none
      }

      await pool.saveProject(expert);

      String? domainMerged;
      if (domain != null && domain.isNotEmpty) {
        var domainExpert = await pool.loadDomain(domain);
        if (domainExpert == null) {
          domainExpert = Expert(
            kind: ExpertKind.domain,
            domain: domain,
            spec: agent.spec.copyWith(name: domain, displayName: domain),
            memory: const ExpertMemory(),
            meta: ExpertMeta(
                source: source, retention: 'experience-only', version: version),
          );
        }
        final merged = await mergeIntoDomain(
          domain: domainExpert,
          project: expert,
          runner: runnerFactory(),
          version: version,
        );
        await pool.saveDomain(merged);
        domainMerged = domain;
      }

      return PublishOutcome(
        projectId: expert.meta.projectId,
        poolPath: '${pool.root.path}/projects/${expert.meta.projectId}',
        domainMerged: domainMerged,
      );
    } catch (e) {
      return PublishOutcome(error: e.toString());
    }
  }

  Future<UseExpertOutcome> useExpert({
    required String domain,
    required String intoPath,
    required String agentName,
    required List<String> repos,
  }) async {
    try {
      final domainExpert = await pool.loadDomain(domain);
      if (domainExpert == null) {
        return UseExpertOutcome(error: 'Domain "$domain" not found');
      }

      final instantiated = instantiate(
        domain: domainExpert,
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

      // Also write spec JSON
      final specFile = File('${targetDir.path}/.crew/specs/$agentName.json');
      specFile.parent.createSync(recursive: true);
      specFile.writeAsStringSync(jsonEncode(instantiated.spec.toJson()));
      writtenPaths.add('.crew/specs/$agentName.json');

      return UseExpertOutcome(writtenPaths: writtenPaths);
    } catch (e) {
      return UseExpertOutcome(error: e.toString());
    }
  }
}
