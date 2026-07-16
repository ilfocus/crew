// crew_cli/lib/src/commands/use_expert.dart
import 'dart:convert';
import 'dart:io';

import 'package:crew_core/crew_core.dart';

class UseExpertOptions {
  final String domain;
  final String intoPath;
  final String agentName;
  final List<String> repos;
  final Directory poolDir;

  const UseExpertOptions({
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

/// Instantiate a domain expert into a target workspace.
///
/// Writes the memory seed (MEMORY.md, domain-notes.md, playbooks/, projects.md)
/// to `<intoPath>/memory/<agentName>/` and the spec JSON to
/// `<intoPath>/.crew/specs/<agentName>.json`.
///
/// Memory files that already exist on disk are skipped to preserve user edits.
Future<UseExpertResult> runUseExpert({
  required UseExpertOptions options,
}) async {
  final pool = ExpertPool(options.poolDir);
  final domain = await pool.loadDomain(options.domain);
  if (domain == null) {
    throw ArgumentError('Domain "${options.domain}" not found in pool');
  }

  final instantiated = instantiate(
    domain: domain,
    agentName: options.agentName,
    newRepos: options.repos,
  );

  final writtenPaths = <String>[];
  final targetDir = Directory(options.intoPath);
  for (final artifact in instantiated.memorySeed) {
    final file = File('${targetDir.path}/${artifact.relativePath}');
    file.parent.createSync(recursive: true);
    // Respect isMemory protection: don't overwrite existing memory files.
    if (artifact.isMemory && file.existsSync()) {
      continue;
    }
    file.writeAsStringSync(artifact.content);
    writtenPaths.add(artifact.relativePath);
  }

  // Also write spec JSON for future publishing.
  final specJson =
      File('${targetDir.path}/.crew/specs/${options.agentName}.json');
  specJson.parent.createSync(recursive: true);
  specJson.writeAsStringSync(jsonEncode(instantiated.spec.toJson()));
  writtenPaths.add('.crew/specs/${options.agentName}.json');

  return UseExpertResult(writtenPaths);
}
