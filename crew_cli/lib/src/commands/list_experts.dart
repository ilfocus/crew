// crew_cli/lib/src/commands/list_experts.dart
import 'dart:io';

import 'package:crew_core/crew_core.dart';

/// List agents in the pool, printing a formatted table to [out].
///
/// 输出按 **agent 层级** 展示（spec §3 新结构）：
/// - 每行一个 agent，显示 id / displayName / domains 数 / projects 数 / version
///
/// Pass [out] (e.g. a [StringBuffer]) in tests to capture output without
/// touching real stdout.
Future<void> runListExperts({
  required Directory poolDir,
  StringSink? out,
}) async {
  final sink = out ?? stdout;
  final pool = AgentPool(poolDir);
  final summaries = await pool.list();

  if (summaries.isEmpty) {
    sink.writeln('Agent pool is empty.');
    return;
  }

  // Print table header.
  sink.writeln('${'AGENT'.padRight(20)} ${'DISPLAY'.padRight(20)} '
      '${'DOMAINS'.padRight(20)} ${'PROJECTS'.padRight(10)} ${'VERSION'}');
  sink.writeln('${'-' * 20} ${'-' * 20} ${'-' * 20} ${'-' * 10} ${'-' * 7}');

  for (final s in summaries) {
    sink.writeln('${s.id.padRight(20)} ${s.displayName.padRight(20)} '
        '${s.domains.join(', ').padRight(20)} '
        '${s.projectCount.toString().padRight(10)} ${s.version}');
  }
}
