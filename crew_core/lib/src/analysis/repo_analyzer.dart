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
}
