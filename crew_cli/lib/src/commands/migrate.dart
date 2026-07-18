// crew_cli/lib/src/commands/migrate.dart
import 'dart:io';

import 'package:crew_core/crew_core.dart';

class MigrateOptions {
  final Directory poolDir;
  final int version;

  const MigrateOptions({
    required this.poolDir,
    required this.version,
  });
}

class MigrateResult {
  final MigrationReport report;
  final String? backupPath;
  const MigrateResult(this.report, this.backupPath);
}

/// 一次性把旧平铺布局（`<poolDir>/projects|domains/...`）迁移到
/// 新 agent 层级布局（`<poolDir>/agents/<id>/...`）。
///
/// 流程：
/// 1. 备份 `<poolDir>` → `<poolDir>.bak`（仅首次；后续运行保留原备份）
/// 2. 调 `migratePool(oldRoot=<poolDir>.bak, newRoot=<poolDir>)` 写新布局
/// 3. 删除 `<poolDir>` 下的旧 `projects/`、`domains/` 子目录（已被 agents/ 取代）
///
/// **幂等**：可重复运行——第二次不再创建备份，只重新跑迁移（覆盖 *.json，
/// 跳过已存在的记忆 md 文件）。
Future<MigrateResult> runMigrate({
  required MigrateOptions options,
}) async {
  final root = options.poolDir;
  final bak = Directory('${root.path}.bak');

  final oldProjectsInRoot = Directory('${root.path}/projects');
  final oldDomainsInRoot = Directory('${root.path}/domains');
  final hasOldInRoot =
      oldProjectsInRoot.existsSync() || oldDomainsInRoot.existsSync();
  final hasOldInBak = bak.existsSync() &&
      (Directory('${bak.path}/projects').existsSync() ||
          Directory('${bak.path}/domains').existsSync());

  if (!hasOldInRoot && !hasOldInBak) {
    // Nothing to migrate
    return MigrateResult(
      const MigrationReport(
        agents: 0,
        domainsMoved: 0,
        projectsMoved: 0,
        needsManualReview: [],
      ),
      null,
    );
  }

  // Source: prefer .bak (preserve original backup); else root (first run).
  Directory oldRoot;
  String? backupPath;
  if (hasOldInBak) {
    oldRoot = bak;
  } else {
    // First run: backup root → root.bak
    await _copyDirectory(root, bak);
    backupPath = bak.path;
    oldRoot = bak;
  }

  // Migrate from oldRoot to root
  final report = await migratePool(
    oldRoot: oldRoot,
    newRoot: root,
    version: options.version,
  );

  // Cleanup old layout in root (now superseded by agents/)
  if (oldProjectsInRoot.existsSync()) {
    await oldProjectsInRoot.delete(recursive: true);
  }
  if (oldDomainsInRoot.existsSync()) {
    await oldDomainsInRoot.delete(recursive: true);
  }

  return MigrateResult(report, backupPath);
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
