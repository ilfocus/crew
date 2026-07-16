// crew_gui/test/state/wizard_controller_assign_test.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/state/wizard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory iosDir;
  setUp(() {
    iosDir = Directory.systemTemp.createTempSync('ios');
    File('${iosDir.path}/Podfile').writeAsStringSync('');
  });
  tearDown(() => iosDir.deleteSync(recursive: true));

  test('autoAssign maps ios template to the ios directory, pm to <all>', () {
    final c = WizardController();
    c.addDirectory(iosDir.path);
    c.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev'));
    c.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'pm'));
    c.autoAssign();
    expect(c.assignments['ios'], [iosDir.path]);
    expect(c.assignments['pm'], [kAllRepos]);
  });

  test('buildConfig produces a CrewConfig honoring assignments', () {
    final c = WizardController();
    c.addDirectory(iosDir.path);
    c.setProjectName('apm');
    c.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev'));
    c.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'pm'));
    c.autoAssign();

    final config = c.buildConfig(createdAt: '2026-07-13');
    expect(config.name, 'apm');
    expect(config.repos.single.path, iosDir.path);
    final ios = config.agents.firstWhere((a) => a.name == 'ios');
    expect(ios.templateRef, 'ios-dev@1');
    expect(ios.repos, [iosDir.path]);
    final pm = config.agents.firstWhere((a) => a.name == 'pm');
    expect(pm.repos, [kAllRepos]);
  });

  test('manual setAssignment overrides', () {
    final c = WizardController();
    c.addDirectory(iosDir.path);
    c.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'backend'));
    c.setAssignment('backend', [iosDir.path]);
    final config = c.buildConfig(createdAt: '2026-07-13');
    expect(config.agents.single.repos, [iosDir.path]);
  });

  test('skipAssign sets all agents to <all> and allows proceeding', () {
    final c = WizardController();
    c.addDirectory(iosDir.path);
    c.setProjectName('apm');
    c.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev'));
    c.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'pm'));
    c.skipAssign();
    expect(c.assignSkipped, isTrue);
    // 所有 agent 都变成 <all>，AI 会在生成时自行分析分配
    expect(c.assignments['ios'], [kAllRepos]);
    expect(c.assignments['pm'], [kAllRepos]);

    final config = c.buildConfig(createdAt: '2026-07-13');
    final ios = config.agents.firstWhere((a) => a.name == 'ios');
    expect(ios.repos, [kAllRepos]);
    expect(ios.isAllRepos, isTrue);
  });

  test('setAssignment after skip clears the skip flag', () {
    final c = WizardController();
    c.addDirectory(iosDir.path);
    c.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev'));
    c.skipAssign();
    expect(c.assignSkipped, isTrue);
    c.setAssignment('ios', [iosDir.path]);
    expect(c.assignSkipped, isFalse);
    expect(c.assignments['ios'], [iosDir.path]);
  });
}
