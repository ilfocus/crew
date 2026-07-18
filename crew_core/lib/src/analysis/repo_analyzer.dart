// crew_core/lib/src/analysis/repo_analyzer.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/agent_template.dart';

/// 模板 ↔ repo 的匹配候选。
///
/// `score` 是命中信号总数（matchGlobs 命中 + 配置文件深度扫描命中）。
/// `signals` 是每个命中信号的简短描述，供 UI 展示给用户判断置信度。
class AssignmentCandidate {
  final String templateId;
  final String repoPath;
  final int score;
  final List<String> signals;
  const AssignmentCandidate(
    this.templateId,
    this.repoPath,
    this.score, {
    this.signals = const [],
  });
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

  /// 简单 Glob 匹配：支持 `*` 作为通配符。
  /// - `*.swift`    → 后缀匹配
  /// - `vite.config.*` → 前缀匹配
  /// - `*.config.ts` → 中间通配
  /// - `Podfile`    → 精确匹配
  bool _matches(String glob, String name) {
    if (glob.isEmpty) return false;
    if (!glob.contains('*')) return name == glob;
    // 把 glob 转成正则：先 escape 正则元字符，再把 * 换成 .*
    final escaped = RegExp.escape(glob).replaceAll(r'\*', '.*');
    return RegExp('^$escaped\$').hasMatch(name);
  }

  /// 主入口：对每个 (template, repo) 组合，返回命中信号。
  ///
  /// 信号来源：
  /// 1. `matchGlobs` 命中 repo 顶层文件/目录名（每个 glob 命中算 1 项）
  /// 2. 关键配置文件深度扫描（package.json/go.mod/Podfile/build.gradle/...）
  ///
  /// 只有 score > 0 的组合才会出现在结果列表里。
  /// `matchGlobs` 为空的模板（如 pm）永远不会产生候选。
  List<AssignmentCandidate> suggest(
    List<AgentTemplate> templates,
    List<String> repoPaths,
  ) {
    final out = <AssignmentCandidate>[];
    for (final repo in repoPaths) {
      final names = _topLevelNames(repo);
      for (final t in templates) {
        if (t.matchGlobs.isEmpty) continue;
        final signals = <String>[];
        // 信号 1：matchGlobs 命中顶层名
        for (final glob in t.matchGlobs) {
          final matched = names.where((n) => _matches(glob, n)).toList();
          if (matched.isEmpty) continue;
          if (matched.length == 1) {
            signals.add(matched.first);
          } else {
            signals.add('$glob ×${matched.length}');
          }
        }
        // 信号 2：关键配置文件深度扫描
        signals.addAll(_deepSignals(repo, t, names));
        if (signals.isNotEmpty) {
          out.add(AssignmentCandidate(t.id, repo, signals.length,
              signals: signals));
        }
      }
    }
    return out;
  }

  /// 针对每个模板的关键配置文件做轻量深度扫描，识别更细粒度的技术栈。
  ///
  /// 设计目标：只读 1-2 个关键文件，不递归，不调子进程。每个命中加一条信号。
  List<String> _deepSignals(
    String repoPath,
    AgentTemplate t,
    List<String> topLevelNames,
  ) {
    switch (t.id) {
      case 'frontend':
        return _frontendSignals(repoPath);
      case 'backend':
        return _backendSignals(repoPath, topLevelNames);
      case 'ios-dev':
        return _iosSignals(repoPath);
      case 'android-dev':
        return _androidSignals(repoPath, topLevelNames);
      case 'python':
        return _pythonSignals(repoPath);
      default:
        return const [];
    }
  }

  /// 前端：读 package.json 识别 React/Vue/Next.js 等。
  List<String> _frontendSignals(String repoPath) {
    final pkg = _readJsonFile(p.join(repoPath, 'package.json'));
    if (pkg == null) return const [];
    final deps = <String, dynamic>{};
    for (final k in const ['dependencies', 'devDependencies']) {
      final m = pkg[k];
      if (m is Map) deps.addAll(m.cast<String, dynamic>());
    }
    final out = <String>[];
    const frameworkMap = {
      'react': 'React',
      'react-dom': 'React',
      'vue': 'Vue',
      'next': 'Next.js',
      'nuxt': 'Nuxt',
      'svelte': 'Svelte',
      '@angular/core': 'Angular',
      'solid-js': 'SolidJS',
      'astro': 'Astro',
    };
    final hit = <String>{};
    for (final dep in deps.keys) {
      final label = frameworkMap[dep];
      if (label != null) hit.add(label);
    }
    out.addAll(hit);
    if (deps.containsKey('typescript') || deps.containsKey('@types/node')) {
      out.add('TypeScript');
    }
    return out;
  }

  /// 后端：识别 Go module 名 / Maven groupId。
  List<String> _backendSignals(String repoPath, List<String> topLevelNames) {
    final out = <String>[];
    // go.mod: 抓 module 路径
    if (topLevelNames.contains('go.mod')) {
      final text = _readTextFile(p.join(repoPath, 'go.mod'));
      if (text != null) {
        final m = RegExp(r'module\s+(\S+)').firstMatch(text);
        if (m != null) out.add('module: ${m.group(1)}');
      }
    }
    // pom.xml: 抓 groupId
    if (topLevelNames.contains('pom.xml')) {
      final text = _readTextFile(p.join(repoPath, 'pom.xml'));
      if (text != null) {
        final m = RegExp(r'<groupId>([^<]+)</groupId>').firstMatch(text);
        if (m != null) out.add('groupId: ${m.group(1)}');
      }
    }
    // Cargo.toml: 抓 [package] 段 name
    if (topLevelNames.contains('Cargo.toml')) {
      final text = _readTextFile(p.join(repoPath, 'Cargo.toml'));
      if (text != null) {
        final m = RegExp(r'name\s*=\s*"([^"]+)"').firstMatch(text);
        if (m != null) out.add('crate: ${m.group(1)}');
      }
    }
    return out;
  }

  /// iOS：读 Podfile 第一行 platform :ios, '14.0'。
  List<String> _iosSignals(String repoPath) {
    final text = _readTextFile(p.join(repoPath, 'Podfile'));
    if (text == null) return const [];
    final m = RegExp(r'''platform\s+:ios,?\s*['"]([^'"]+)['"]''').firstMatch(text);
    final out = <String>[];
    if (m != null) out.add('iOS ${m.group(1)}');
    // 抽取 target 名（前 3 个）
    final targetRegex = RegExp(r'''target\s+['"]([^'"]+)['"]''');
    final targets = targetRegex
        .allMatches(text)
        .map((m) => m.group(1)!)
        .take(3)
        .toList();
    if (targets.isNotEmpty) out.add('targets: ${targets.join(', ')}');
    return out;
  }

  /// Android：读 build.gradle(.kts) 提取 applicationId / namespace。
  List<String> _androidSignals(String repoPath, List<String> topLevelNames) {
    final gradleFile = topLevelNames.contains('build.gradle.kts')
        ? 'build.gradle.kts'
        : (topLevelNames.contains('build.gradle') ? 'build.gradle' : null);
    if (gradleFile == null) return const [];
    final text = _readTextFile(p.join(repoPath, gradleFile));
    if (text == null) return const [];
    final out = <String>[];
    final appId = RegExp(r'''applicationId\s+["']([^"']+)["']''').firstMatch(text);
    if (appId != null) out.add('applicationId: ${appId.group(1)}');
    final ns = RegExp(r'''namespace\s+["']([^"']+)["']''').firstMatch(text);
    if (ns != null) out.add('namespace: ${ns.group(1)}');
    return out;
  }

  /// Python：扫 requirements.txt 抽取关键包（django/flask/fastapi/numpy/pandas 等）。
  List<String> _pythonSignals(String repoPath) {
    final candidates = const [
      'requirements.txt',
      'pyproject.toml',
    ];
    String? text;
    for (final name in candidates) {
      text = _readTextFile(p.join(repoPath, name));
      if (text != null) break;
    }
    if (text == null) return const [];
    final known = const {
      'django': 'Django',
      'flask': 'Flask',
      'fastapi': 'FastAPI',
      'numpy': 'NumPy',
      'pandas': 'Pandas',
      'scipy': 'SciPy',
      'tensorflow': 'TensorFlow',
      'torch': 'PyTorch',
      'requests': 'requests',
      'aiohttp': 'aiohttp',
      'pytest': 'pytest',
    };
    final hit = <String>{};
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      // 处理 "django>=4.0" / "django==4.0" 等
      final pkgName = trimmed
          .split(RegExp(r'[=<>!~;\s]'))[0]
          .toLowerCase()
          .replaceAll('-', '_');
      final label = known[pkgName] ?? known[pkgName.replaceAll('_', '-')];
      if (label != null) hit.add(label);
    }
    return hit.toList();
  }

  Map<String, dynamic>? _readJsonFile(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    try {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? _readTextFile(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    try {
      return f.readAsStringSync();
    } catch (_) {
      return null;
    }
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
