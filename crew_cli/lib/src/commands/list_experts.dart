// crew_cli/lib/src/commands/list_experts.dart
import 'dart:io';

import 'package:crew_core/crew_core.dart';

/// List experts in the pool, printing a formatted table to [out].
///
/// Pass [out] (e.g. a [StringBuffer]) in tests to capture output without
/// touching real stdout.
Future<void> runListExperts({
  required Directory poolDir,
  StringSink? out,
}) async {
  final sink = out ?? stdout;
  final pool = ExpertPool(poolDir);
  final summaries = await pool.list();

  if (summaries.isEmpty) {
    sink.writeln('Expert pool is empty.');
    return;
  }

  // Print table header.
  sink.writeln(
      '${'KIND'.padRight(10)} ${'ID/DOMAIN'.padRight(40)} ${'VERSION'}');
  sink.writeln('${'-' * 10} ${'-' * 40} ${'-' * 7}');

  for (final s in summaries) {
    final kind = s.kind == ExpertKind.project ? 'project' : 'domain';
    sink.writeln(
        '${kind.padRight(10)} ${s.id.padRight(40)} ${s.version}');
  }
}
