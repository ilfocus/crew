// crew_core/test/expert/workspace_reader_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

AgentSpec _iosSpec() => const AgentSpec(
      name: 'ios',
      displayName: '小i',
      repos: ['~/bm_app/ios'],
      role: 'iOS 开发工程师',
      coordinates: '路径 ~/bm_app/ios',
      moduleStructure: 'Core/ 单例',
      keyFiles: [KeyFile('Core/BMApm.swift:279', '上报总线')],
      dataflow: '采集 → 神策',
      memoryConvention: '开工前读 MEMORY.md',
      conventions: ['默认在 develop/apm 工作'],
      personality: '严谨',
      principles: ['不引入未测试依赖'],
      techStack: ['Swift', 'SwiftUI'],
      sdks: ['SensorsSDK'],
      difficulties: ['线程安全'],
      source: 'opensource',
      github: 'https://github.com/foo/bar',
    );

/// 构造一个含 spec + 完整 memory 的 temp workspace。
Directory _fullWorkspace() {
  final root = Directory.systemTemp.createTempSync('ws_reader');
  // .crew/specs/ios.json
  final specFile = File('${root.path}/.crew/specs/ios.json');
  specFile.parent.createSync(recursive: true);
  specFile.writeAsStringSync(jsonEncode(_iosSpec().toJson()));

  // memory/ios/...
  File('${root.path}/memory/ios/MEMORY.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('# Memory Index');
  File('${root.path}/memory/ios/project-notes.md')
      .writeAsStringSync('L1 notes');
  File('${root.path}/memory/ios/solved/issue1.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('fix issue 1');
  File('${root.path}/memory/ios/solved/README.md')
      .writeAsStringSync('template');
  File('${root.path}/memory/ios/playbooks/pb1.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('playbook 1');
  File('${root.path}/memory/ios/playbooks/README.md')
      .writeAsStringSync('template');
  return root;
}

void main() {
  group('readAgent', () {
    test('reads spec + full memory; skips README.md in solved/playbooks', () async {
      final root = _fullWorkspace();
      addTearDown(() => root.deleteSync(recursive: true));

      final reader = WorkspaceReader(root);
      final agent = await reader.readAgent('ios');

      expect(agent, isNotNull);
      // spec round-trips equivalently
      expect(agent!.spec.name, 'ios');
      expect(agent.spec.displayName, '小i');
      expect(agent.spec.role, 'iOS 开发工程师');
      expect(agent.spec.coordinates, '路径 ~/bm_app/ios');
      expect(agent.spec.moduleStructure, 'Core/ 单例');
      expect(agent.spec.keyFiles.length, 1);
      expect(agent.spec.keyFiles.first.path, 'Core/BMApm.swift:279');
      expect(agent.spec.keyFiles.first.purpose, '上报总线');
      expect(agent.spec.dataflow, '采集 → 神策');
      expect(agent.spec.memoryConvention, '开工前读 MEMORY.md');
      expect(agent.spec.conventions, ['默认在 develop/apm 工作']);
      expect(agent.spec.personality, '严谨');
      expect(agent.spec.principles, ['不引入未测试依赖']);
      expect(agent.spec.techStack, ['Swift', 'SwiftUI']);
      expect(agent.spec.sdks, ['SensorsSDK']);
      expect(agent.spec.difficulties, ['线程安全']);
      expect(agent.spec.source, 'opensource');
      expect(agent.spec.github, 'https://github.com/foo/bar');

      // memory
      expect(agent.memory.index, '# Memory Index');
      expect(agent.memory.notes, 'L1 notes');
      expect(agent.memory.solved.length, 1);
      expect(agent.memory.solved.first.path, 'issue1.md');
      expect(agent.memory.solved.first.content, 'fix issue 1');
      expect(agent.memory.playbooks.length, 1);
      expect(agent.memory.playbooks.first.path, 'pb1.md');
      expect(agent.memory.playbooks.first.content, 'playbook 1');
      // projects always empty in workspace
      expect(agent.memory.projects, isEmpty);
    });

    test('returns null when spec file does not exist', () async {
      final root = _fullWorkspace();
      addTearDown(() => root.deleteSync(recursive: true));

      final reader = WorkspaceReader(root);
      final agent = await reader.readAgent('nonexistent');
      expect(agent, isNull);
    });

    test('empty memory dir (no solved/playbooks) → empty lists, not crash',
        () async {
      final root = Directory.systemTemp.createTempSync('ws_empty_mem');
      addTearDown(() => root.deleteSync(recursive: true));
      // spec only, no memory dir at all
      final specFile = File('${root.path}/.crew/specs/ios.json');
      specFile.parent.createSync(recursive: true);
      specFile.writeAsStringSync(jsonEncode(_iosSpec().toJson()));

      final reader = WorkspaceReader(root);
      final agent = await reader.readAgent('ios');

      expect(agent, isNotNull);
      expect(agent!.spec.name, 'ios');
      expect(agent.memory.index, '');
      expect(agent.memory.notes, '');
      expect(agent.memory.solved, isEmpty);
      expect(agent.memory.playbooks, isEmpty);
      expect(agent.memory.projects, isEmpty);
    });

    test('memory dir exists but missing MEMORY.md / project-notes.md defaults to empty',
        () async {
      final root = Directory.systemTemp.createTempSync('ws_partial_mem');
      addTearDown(() => root.deleteSync(recursive: true));
      final specFile = File('${root.path}/.crew/specs/ios.json');
      specFile.parent.createSync(recursive: true);
      specFile.writeAsStringSync(jsonEncode(_iosSpec().toJson()));
      // only solved/issue1.md, no MEMORY.md / project-notes.md / playbooks/
      File('${root.path}/memory/ios/solved/issue1.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('fix');

      final reader = WorkspaceReader(root);
      final agent = await reader.readAgent('ios');

      expect(agent, isNotNull);
      expect(agent!.memory.index, '');
      expect(agent.memory.notes, '');
      expect(agent.memory.solved.length, 1);
      expect(agent.memory.solved.first.path, 'issue1.md');
      expect(agent.memory.playbooks, isEmpty);
    });
  });

  group('readAgents', () {
    test('returns list with 1 agent for the full workspace', () async {
      final root = _fullWorkspace();
      addTearDown(() => root.deleteSync(recursive: true));

      final reader = WorkspaceReader(root);
      final agents = await reader.readAgents();

      expect(agents.length, 1);
      expect(agents.first.spec.name, 'ios');
      expect(agents.first.memory.index, '# Memory Index');
      expect(agents.first.memory.solved.length, 1);
      expect(agents.first.memory.playbooks.length, 1);
    });

    test('returns empty list when .crew/specs/ does not exist', () async {
      final root = Directory.systemTemp.createTempSync('ws_no_specs');
      addTearDown(() => root.deleteSync(recursive: true));

      final reader = WorkspaceReader(root);
      final agents = await reader.readAgents();
      expect(agents, isEmpty);
    });

    test('reads multiple agents when multiple spec files exist', () async {
      final root = Directory.systemTemp.createTempSync('ws_multi');
      addTearDown(() => root.deleteSync(recursive: true));
      // ios spec
      final iosSpec = File('${root.path}/.crew/specs/ios.json');
      iosSpec.parent.createSync(recursive: true);
      iosSpec.writeAsStringSync(jsonEncode(_iosSpec().toJson()));
      // pm spec (minimal)
      final pmSpec = File('${root.path}/.crew/specs/pm.json');
      pmSpec.writeAsStringSync(jsonEncode(const AgentSpec(
        name: 'pm',
        displayName: '小P',
        repos: [],
        role: 'PM',
        coordinates: '',
        moduleStructure: '',
        keyFiles: [],
        dataflow: '',
        memoryConvention: '',
        conventions: [],
      ).toJson()));
      // memory only for ios
      File('${root.path}/memory/ios/MEMORY.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('# IOS');

      final reader = WorkspaceReader(root);
      final agents = await reader.readAgents();
      expect(agents.length, 2);
      final names = agents.map((a) => a.spec.name).toSet();
      expect(names, containsAll(<String>['ios', 'pm']));
      // ios has memory, pm does not (defaults to empty)
      final ios = agents.firstWhere((a) => a.spec.name == 'ios');
      final pm = agents.firstWhere((a) => a.spec.name == 'pm');
      expect(ios.memory.index, '# IOS');
      expect(pm.memory.index, '');
    });
  });
}
