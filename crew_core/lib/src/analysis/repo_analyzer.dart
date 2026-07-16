// crew_core/lib/src/analysis/repo_analyzer.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/agent_template.dart';

class AssignmentCandidate {
  final String templateId;
  final String repoPath;
  final int score;
  const AssignmentCandidate(this.templateId, this.repoPath, this.score);
}

class RepoAnalyzer {
  /// 返回顶层文件/目录的名字列表（不递归，够用且快）。
  List<String> _topLevelNames(String repoPath) {
    final dir = Directory(repoPath);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .map((e) => p.basename(e.path))
        .toList(growable: false);
  }

  bool _matches(String glob, String name) {
    if (glob.startsWith('*.')) {
      return name.endsWith(glob.substring(1)); // "*.swift" -> ".swift"
    }
    return name == glob;
  }

  List<AssignmentCandidate> suggest(
    List<AgentTemplate> templates,
    List<String> repoPaths,
  ) {
    final out = <AssignmentCandidate>[];
    for (final repo in repoPaths) {
      final names = _topLevelNames(repo);
      for (final t in templates) {
        var score = 0;
        for (final glob in t.matchGlobs) {
          if (names.any((n) => _matches(glob, n))) score++;
        }
        if (score > 0) out.add(AssignmentCandidate(t.id, repo, score));
      }
    }
    return out;
  }

  /// 读取 repo 的 `.git/config` 获取 remote origin URL（纯文件读取，不起子进程）。
  /// 返回 null 表示无 git remote 或文件不存在。
  String? gitRemoteUrl(String repoPath) {
    final config = File('${p.join(repoPath, '.git', 'config')}');
    if (!config.existsSync()) return null;
    final lines = config.readAsLinesSync();
    var inOrigin = false;
    for (final line in lines) {
      if (line.trim() == '[remote "origin"]') {
        inOrigin = true;
        continue;
      }
      if (inOrigin) {
        if (line.startsWith('[')) {
          inOrigin = false;
          continue;
        }
        final trimmed = line.trim();
        if (trimmed.startsWith('url =') || trimmed.startsWith('url=')) {
          final eq = trimmed.indexOf('=');
          if (eq >= 0) return trimmed.substring(eq + 1).trim();
        }
      }
    }
    return null;
  }
}
