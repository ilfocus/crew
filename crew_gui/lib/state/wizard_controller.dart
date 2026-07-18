// crew_gui/lib/state/wizard_controller.dart
import 'package:crew_core/crew_core.dart';
import 'package:flutter/foundation.dart';
import 'wizard_step.dart';

class WizardController extends ChangeNotifier {
  final RepoAnalyzer analyzer;
  WizardController({RepoAnalyzer? analyzer})
      : analyzer = analyzer ?? RepoAnalyzer();

  final List<String> directories = [];
  final List<AgentTemplate> selectedTemplates = [];

  /// 最近一次扫描结果（autoDetect / autoAssign 产出）。
  /// 供 UI 显示命中信号 chip。目录变化时清空。
  List<AssignmentCandidate> _lastScan = const [];
  List<AssignmentCandidate> get lastScan => _lastScan;

  void addDirectory(String path) {
    if (path.isEmpty || directories.contains(path)) return;
    directories.add(path);
    _lastScan = const [];
    notifyListeners();
  }

  void removeDirectory(String path) {
    directories.remove(path);
    _lastScan = const [];
    notifyListeners();
  }

  bool isSelected(AgentTemplate t) =>
      selectedTemplates.any((x) => x.ref == t.ref);

  void toggleTemplate(AgentTemplate t) {
    if (isSelected(t)) {
      selectedTemplates.removeWhere((x) => x.ref == t.ref);
    } else {
      selectedTemplates.add(t);
    }
    notifyListeners();
  }

  String agentNameFor(AgentTemplate t) {
    final base = t.defaultName;
    final others = selectedTemplates.where((x) => x.ref != t.ref);
    if (!others.any((x) => x.defaultName == base)) return base;
    // 重名：按其在选中列表中的序号加后缀
    final idx = selectedTemplates.indexWhere((x) => x.ref == t.ref);
    return '$base${idx + 1}';
  }

  // --- 关联与配置（Task 6） ---
  final Map<String, List<String>> assignments = {};
  String projectName = '';
  String workspaceParent = '';
  bool assignSkipped = false;

  bool _isPm(AgentTemplate t) => t.id == 'pm';

  /// 在已选模板集合内分配目录。不选专家。
  /// 扫描结果会缓存到 [lastScan]，供 UI 显示信号。
  void autoAssign() {
    assignSkipped = false;
    _lastScan = analyzer.suggest(selectedTemplates, directories);
    for (final t in selectedTemplates) {
      final name = agentNameFor(t);
      if (_isPm(t)) {
        assignments[name] = [kAllRepos];
        continue;
      }
      final mine = _lastScan.where((c) => c.templateId == t.id).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      assignments[name] = mine.isNotEmpty ? [mine.first.repoPath] : <String>[];
    }
    notifyListeners();
  }

  /// 智能识别：用全集模板扫描所有目录，把命中模板自动选中并关联到最高分 repo。
  /// 扫到任何技术栈就自动加 PM。保留用户已选模板，只追加推荐的。
  void autoDetect(List<AgentTemplate> allTemplates) {
    if (directories.isEmpty) {
      _lastScan = const [];
      notifyListeners();
      return;
    }
    _lastScan = analyzer.suggest(allTemplates, directories);
    final hitIds = _lastScan.map((c) => c.templateId).toSet();

    // 把命中模板加进 selectedTemplates（去重追加，不打乱已有顺序）
    for (final id in hitIds) {
      final idx = allTemplates.indexWhere((t) => t.id == id);
      if (idx < 0) continue;
      final t = allTemplates[idx];
      if (!isSelected(t)) selectedTemplates.add(t);
    }

    // 任何技术栈命中就自动加 PM
    if (hitIds.isNotEmpty) {
      AgentTemplate? pm;
      for (final t in allTemplates) {
        if (t.id == 'pm') {
          pm = t;
          break;
        }
      }
      if (pm == null) {
        for (final t in kBuiltinTemplates) {
          if (t.id == 'pm') {
            pm = t;
            break;
          }
        }
      }
      if (pm != null && !isSelected(pm)) selectedTemplates.add(pm);
    }

    // 关联目录：每个非 PM 模板关联到最高分 repo；PM 关联所有
    assignSkipped = false;
    for (final t in selectedTemplates) {
      final name = agentNameFor(t);
      if (_isPm(t)) {
        assignments[name] = [kAllRepos];
        continue;
      }
      final mine = _lastScan
          .where((c) => c.templateId == t.id)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      assignments[name] = mine.isNotEmpty ? [mine.first.repoPath] : <String>[];
    }
    notifyListeners();
  }

  /// 某模板的命中信号总数（PM 永远 0；未扫描过也返回 0）。
  int signalCountFor(AgentTemplate t) {
    if (_isPm(t)) return 0;
    return _lastScan
        .where((c) => c.templateId == t.id)
        .fold(0, (s, c) => s + c.signals.length);
  }

  /// 某模板的所有命中信号（用于展开详情 / tooltip）。
  List<String> signalsFor(AgentTemplate t) {
    if (_isPm(t)) return const [];
    final out = <String>[];
    for (final c in _lastScan.where((c) => c.templateId == t.id)) {
      out.addAll(c.signals);
    }
    return out;
  }

  void skipAssign() {
    assignSkipped = true;
    for (final t in selectedTemplates) {
      final name = agentNameFor(t);
      assignments[name] = [kAllRepos];
    }
    notifyListeners();
  }

  void setAssignment(String agentName, List<String> repos) {
    assignSkipped = false;
    assignments[agentName] = repos;
    notifyListeners();
  }

  void setProjectName(String name) {
    projectName = name;
    notifyListeners();
  }

  void setWorkspaceParent(String path) {
    workspaceParent = path;
    notifyListeners();
  }

  CrewConfig buildConfig({required String createdAt}) {
    final agents = <Agent>[];
    for (final t in selectedTemplates) {
      final name = agentNameFor(t);
      final repos = _isPm(t)
          ? const [kAllRepos]
          : (assignments[name] ?? const <String>[]);
      agents.add(Agent(name: name, templateRef: t.ref, repos: repos));
    }
    return CrewConfig(
      version: 1,
      name: projectName,
      createdAt: createdAt,
      repos: directories.map((d) => Repo(d)).toList(),
      targets: targets.toList()..sort(),
      runner: runner,
      cliTool: cliTool,
      agents: agents,
    );
  }

  // --- 目标与 Runner（Task 7） ---
  final Set<String> targets = {'claude', 'codex'};
  String runner = 'cli';
  String cliTool = 'claude';

  void toggleTarget(String target) {
    if (targets.contains(target)) {
      if (targets.length == 1) return; // 至少保留一个
      targets.remove(target);
    } else {
      targets.add(target);
    }
    notifyListeners();
  }

  void setCliTool(String tool) {
    cliTool = tool;
    notifyListeners();
  }

  bool canProceed(WizardStep step) {
    switch (step) {
      case WizardStep.directories:
        return directories.isNotEmpty;
      case WizardStep.agents:
        return selectedTemplates.isNotEmpty;
      case WizardStep.assign:
        if (assignSkipped) return true;
        return selectedTemplates
            .where((t) => !_isPm(t))
            .every((t) => (assignments[agentNameFor(t)] ?? const []).isNotEmpty);
      case WizardStep.targets:
        return targets.isNotEmpty;
      case WizardStep.preview:
        return projectName.isNotEmpty && workspaceParent.isNotEmpty;
      case WizardStep.done:
        return true;
    }
  }
}
