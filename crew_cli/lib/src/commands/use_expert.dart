// crew_cli/lib/src/commands/use_expert.dart
import 'dart:convert';
import 'dart:io';

import 'package:crew_core/crew_core.dart';

class UseExpertOptions {
  /// 池侧 agent 个体 id（spec §2.1）。
  final String agentId;

  /// 要实例化的领域（agent 下的 domains/<domain>/）。
  final String domain;

  /// 目标 workspace 根路径。
  final String intoPath;

  /// 新 workspace 中 agent 名（写入 `.crew/specs/<agentName>.json` 与
  /// `memory/<agentName>/`）。
  final String agentName;

  /// 新 workspace 的仓库路径（spec.repos）。
  final List<String> repos;

  final Directory poolDir;

  const UseExpertOptions({
    required this.agentId,
    required this.domain,
    required this.intoPath,
    required this.agentName,
    required this.repos,
    required this.poolDir,
  });
}

class UseExpertResult {
  final List<String> writtenPaths;
  const UseExpertResult(this.writtenPaths);
}

/// 从池中实例化某 agent 的某领域专长到目标 workspace（spec §6 instantiate）。
///
/// 流程：
/// 1. `AgentPool.load(agentId)` 取 AgentProfile（含 core 身份）
/// 2. `AgentPool.loadDomain(agentId, domain)` 取 DomainExpertise（L2）
/// 3. `instantiate(core, domain, agentName, newRepos)` 生成 spec + memory seed
/// 4. 写入目标 workspace：
///    - `memory/<agentName>/*`（isMemory 文件已存在则跳过，保护用户编辑）
///    - `.crew/specs/<agentName>.json`
///
/// **绝不带** L1 specifics（solved/keyFiles/coordinates）——instantiator 已保证。
Future<UseExpertResult> runUseExpert({
  required UseExpertOptions options,
}) async {
  final pool = AgentPool(options.poolDir);

  // 1. Load agent profile (need core)
  final profile = await pool.load(options.agentId);
  if (profile == null) {
    throw ArgumentError(
        'Agent "${options.agentId}" not found in pool ${options.poolDir.path}');
  }

  // 2. Load domain expertise
  final domain = await pool.loadDomain(options.agentId, options.domain);
  if (domain == null) {
    throw ArgumentError('Domain "${options.domain}" not found for agent '
        '"${options.agentId}" in pool ${options.poolDir.path}');
  }

  // 3. Instantiate
  final instantiated = instantiate(
    core: profile.core,
    domain: domain,
    agentName: options.agentName,
    newRepos: options.repos,
  );

  // 4. Write to target workspace
  final writtenPaths = <String>[];
  final targetDir = Directory(options.intoPath);
  for (final artifact in instantiated.memorySeed) {
    final file = File('${targetDir.path}/${artifact.relativePath}');
    file.parent.createSync(recursive: true);
    // 记忆保护：isMemory 文件已存在则不覆盖
    if (artifact.isMemory && file.existsSync()) {
      continue;
    }
    file.writeAsStringSync(artifact.content);
    writtenPaths.add(artifact.relativePath);
  }

  // spec JSON（供未来 publish 复用）
  final specJson =
      File('${targetDir.path}/.crew/specs/${options.agentName}.json');
  specJson.parent.createSync(recursive: true);
  specJson.writeAsStringSync(jsonEncode(instantiated.spec.toJson()));
  writtenPaths.add('.crew/specs/${options.agentName}.json');

  return UseExpertResult(writtenPaths);
}
