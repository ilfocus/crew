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

  void addDirectory(String path) {
    if (path.isEmpty || directories.contains(path)) return;
    directories.add(path);
    notifyListeners();
  }

  void removeDirectory(String path) {
    directories.remove(path);
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

  bool _isPm(AgentTemplate t) => t.id == 'pm';

  void autoAssign() {
    final candidates = analyzer.suggest(selectedTemplates, directories);
    for (final t in selectedTemplates) {
      final name = agentNameFor(t);
      if (_isPm(t)) {
        assignments[name] = [kAllRepos];
        continue;
      }
      final mine = candidates.where((c) => c.templateId == t.id).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      assignments[name] = mine.isNotEmpty ? [mine.first.repoPath] : <String>[];
    }
    notifyListeners();
  }

  void setAssignment(String agentName, List<String> repos) {
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
