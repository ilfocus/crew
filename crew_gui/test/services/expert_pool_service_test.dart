// crew_gui/test/services/expert_pool_service_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/services/expert_pool_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory poolDir;
  late Directory workspaceDir;
  late ExpertPoolService service;

  setUp(() {
    poolDir = Directory.systemTemp.createTempSync('pool');
    workspaceDir = _createWorkspace();
    service = ExpertPoolService(
      ExpertPool(poolDir),
      runnerFactory: () => FakeRunner((_, __) => ''),
    );
  });

  tearDown(() {
    poolDir.deleteSync(recursive: true);
    workspaceDir.deleteSync(recursive: true);
  });

  test('publish with experience-only and domain creates project + domain experts',
      () async {
    final outcome = await service.publish(
      workspacePath: workspaceDir.path,
      agentName: 'ios',
      retention: 'experience-only',
      source: 'opensource',
      domain: 'quant',
      version: 1,
    );
    expect(outcome.isSuccess, isTrue);
    expect(outcome.projectId, isNotNull);
    expect(outcome.domainMerged, 'quant');

    final list = await service.list();
    expect(list.length, 2);
    expect(list.any((e) => e.kind == ExpertKind.project), isTrue);
    expect(list.any((e) => e.kind == ExpertKind.domain), isTrue);

    final domain = await service.pool.loadDomain('quant');
    expect(domain, isNotNull);
    expect(domain!.meta.learnedProjectIds, contains(outcome.projectId));
  });

  test('useExpert writes memory files without solved/', () async {
    // First publish to create the domain expert
    await service.publish(
      workspacePath: workspaceDir.path,
      agentName: 'ios',
      retention: 'experience-only',
      source: 'opensource',
      domain: 'quant',
      version: 1,
    );

    final targetDir = Directory.systemTemp.createTempSync('target');
    addTearDown(() => targetDir.deleteSync(recursive: true));

    final outcome = await service.useExpert(
      domain: 'quant',
      intoPath: targetDir.path,
      agentName: 'ios-new',
      repos: ['~/newproj/ios'],
    );
    expect(outcome.isSuccess, isTrue);
    expect(outcome.writtenPaths, isNotEmpty);

    // domain-notes.md exists
    expect(
      File('${targetDir.path}/memory/ios-new/domain-notes.md').existsSync(),
      isTrue,
    );
    // playbooks/ directory exists
    expect(
      Directory('${targetDir.path}/memory/ios-new/playbooks').existsSync(),
      isTrue,
    );
    // solved/ directory does NOT exist (L1 specifics not carried over)
    expect(
      Directory('${targetDir.path}/memory/ios-new/solved').existsSync(),
      isFalse,
    );
    // spec JSON written
    expect(
      File('${targetDir.path}/.crew/specs/ios-new.json').existsSync(),
      isTrue,
    );
  });

  test('publish with none returns null projectId', () async {
    final outcome = await service.publish(
      workspacePath: workspaceDir.path,
      agentName: 'ios',
      retention: 'none',
      source: 'opensource',
      version: 1,
    );
    expect(outcome.isSuccess, isTrue);
    expect(outcome.projectId, isNull);
  });

  test('useExpert with non-existent domain returns error', () async {
    final outcome = await service.useExpert(
      domain: 'no-such-domain',
      intoPath: '/tmp/whatever',
      agentName: 'x',
      repos: [],
    );
    expect(outcome.isSuccess, isFalse);
    expect(outcome.error, isNotNull);
    expect(outcome.error, contains('not found'));
  });
}

/// Builds a temp workspace with one agent (ios) that has spec + memory.
Directory _createWorkspace() {
  final root = Directory.systemTemp.createTempSync('ws');
  final spec = const AgentSpec(
    name: 'ios',
    displayName: '小i',
    repos: ['~/proj/ios'],
    role: 'iOS 开发工程师',
    coordinates: '路径 ~/proj/ios',
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
  );
  final specFile = File('${root.path}/.crew/specs/ios.json');
  specFile.parent.createSync(recursive: true);
  specFile.writeAsStringSync(jsonEncode(spec.toJson()));

  File('${root.path}/memory/ios/MEMORY.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('# Memory Index');
  File('${root.path}/memory/ios/project-notes.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('L1 notes about iOS');
  File('${root.path}/memory/ios/solved/issue1.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('fixed crash in BMApm');
  File('${root.path}/memory/ios/playbooks/pb1.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('playbook for release');

  return root;
}
