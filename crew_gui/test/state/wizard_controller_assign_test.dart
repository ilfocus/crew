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

  group('autoDetect', () {
    test('selects hit templates and adds PM automatically', () {
      final c = WizardController();
      c.addDirectory(iosDir.path);
      expect(c.selectedTemplates, isEmpty);

      c.autoDetect(kBuiltinTemplates);

      // ios-dev 命中 Podfile，应自动选中
      final hasIos = c.selectedTemplates.any((t) => t.id == 'ios-dev');
      expect(hasIos, isTrue);
      // PM 也应自动选中
      final hasPm = c.selectedTemplates.any((t) => t.id == 'pm');
      expect(hasPm, isTrue);
      // ios agent 关联到 ios 目录
      expect(c.assignments['ios'], [iosDir.path]);
      // pm 关联到 <all>
      expect(c.assignments['pm'], [kAllRepos]);
    });

    test('does not add PM when nothing matches', () {
      final empty = Directory.systemTemp.createTempSync('empty_repo');
      addTearDown(() => empty.deleteSync(recursive: true));
      final c = WizardController();
      c.addDirectory(empty.path);
      c.autoDetect(kBuiltinTemplates);
      expect(c.selectedTemplates, isEmpty);
      expect(c.assignments, isEmpty);
    });

    test('no-op without directories', () {
      final c = WizardController();
      c.autoDetect(kBuiltinTemplates);
      expect(c.selectedTemplates, isEmpty);
      expect(c.lastScan, isEmpty);
    });

    test('preserves user-selected templates; only appends detected ones', () {
      // 用户先手动选了 backend（不匹配 ios 目录）
      final c = WizardController();
      c.addDirectory(iosDir.path);
      c.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'backend'));
      expect(c.selectedTemplates.single.id, 'backend');

      c.autoDetect(kBuiltinTemplates);

      // backend 仍在
      expect(c.selectedTemplates.any((t) => t.id == 'backend'), isTrue);
      // ios-dev 追加进来了
      expect(c.selectedTemplates.any((t) => t.id == 'ios-dev'), isTrue);
      // PM 也加进来了
      expect(c.selectedTemplates.any((t) => t.id == 'pm'), isTrue);
    });

    test('multi-repo: assigns each template to its best-matching repo', () {
      final tmp = Directory.systemTemp.createTempSync('auto_multi');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final ios = Directory('${tmp.path}/ios')..createSync();
      File('${ios.path}/Podfile').writeAsStringSync('');
      final py = Directory('${tmp.path}/py')..createSync();
      File('${py.path}/requirements.txt').writeAsStringSync('');

      final c = WizardController();
      c.addDirectory(ios.path);
      c.addDirectory(py.path);
      c.autoDetect(kBuiltinTemplates);

      // ios-dev 关联到 ios 目录，python 关联到 py 目录
      expect(c.assignments['ios'], [ios.path]);
      expect(c.assignments['python'], [py.path]);
      expect(c.assignments['pm'], [kAllRepos]);
    });

    test('lastScan is populated and signalCountFor returns counts', () {
      final c = WizardController();
      c.addDirectory(iosDir.path);
      c.autoDetect(kBuiltinTemplates);

      final ios = kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev');
      expect(c.lastScan, isNotEmpty);
      expect(c.signalCountFor(ios), greaterThan(0));
      // PM 的 signalCount 永远是 0
      final pm = kBuiltinTemplates.firstWhere((t) => t.id == 'pm');
      expect(c.signalCountFor(pm), 0);
    });

    test('lastScan is cleared when directory changes', () {
      final c = WizardController();
      c.addDirectory(iosDir.path);
      c.autoDetect(kBuiltinTemplates);
      expect(c.lastScan, isNotEmpty);

      // 添加新目录，lastScan 应被清空
      final py = Directory.systemTemp.createTempSync('py');
      addTearDown(() => py.deleteSync(recursive: true));
      c.addDirectory(py.path);
      expect(c.lastScan, isEmpty);

      // 重新扫描
      c.autoDetect(kBuiltinTemplates);
      expect(c.lastScan, isNotEmpty);
    });
  });
}
