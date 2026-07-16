// crew_cli/test/publish_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:crew_cli/src/commands/publish.dart';
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

/// Build a temp workspace with a spec + memory for the `ios` agent.
Directory _fullWorkspace() {
  final root = Directory.systemTemp.createTempSync('cli_ws');
  final specFile = File('${root.path}/.crew/specs/ios.json');
  specFile.parent.createSync(recursive: true);
  specFile.writeAsStringSync(jsonEncode(_iosSpec().toJson()));

  File('${root.path}/memory/ios/MEMORY.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('# Memory Index');
  File('${root.path}/memory/ios/project-notes.md')
      .writeAsStringSync('L1 notes with /Users/bm/app/ios path');
  File('${root.path}/memory/ios/solved/issue1.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('fix issue 1 at Core/Foo.swift:42');
  File('${root.path}/memory/ios/solved/README.md')
      .writeAsStringSync('template');
  File('${root.path}/memory/ios/playbooks/pb1.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('use foo/bar.dart:12 carefully');
  File('${root.path}/memory/ios/playbooks/README.md')
      .writeAsStringSync('template');
  return root;
}

void main() {
  late Directory workspace;
  late Directory poolDir;

  setUp(() {
    workspace = _fullWorkspace();
    poolDir = Directory.systemTemp.createTempSync('cli_pool');
  });

  tearDown(() {
    workspace.deleteSync(recursive: true);
    poolDir.deleteSync(recursive: true);
  });

  group('runPublish — experience-only', () {
    test('pool has project expert with no keyFiles and redacted notes', () async {
      final result = await runPublish(
        options: PublishOptions(
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'experience-only',
          source: 'opensource',
          poolDir: poolDir,
          version: 1,
        ),
      );

      expect(result.projectId, isNotNull);
      expect(result.poolPath, isNotNull);
      expect(result.domainMerged, isNull);

      final pool = ExpertPool(poolDir);
      final loaded = await pool.loadProject(result.projectId!);
      expect(loaded, isNotNull);
      expect(loaded!.kind, ExpertKind.project);
      // experience-only clears keyFiles / coordinates / repos / solved
      expect(loaded.spec.keyFiles, isEmpty);
      expect(loaded.spec.coordinates, '');
      expect(loaded.spec.repos, isEmpty);
      expect(loaded.memory.solved, isEmpty);
      // transferable fields preserved
      expect(loaded.spec.personality, '严谨');
      expect(loaded.spec.techStack, ['Swift', 'SwiftUI']);
    });
  });

  group('runPublish — with domain merge', () {
    test('creates domain expert; learnedProjectIds contains the project',
        () async {
      final runner = FakeRunner(
        (dir, t) => '{}',
        distillResponder: (prompt) =>
            '{"domainNotes":"quant abstraction","playbooks":'
            '[{"path":"playbooks/quant.md","content":"quant steps"}]}',
      );

      final result = await runPublish(
        options: PublishOptions(
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'experience-only',
          source: 'opensource',
          poolDir: poolDir,
          domain: 'quant',
          version: 1,
        ),
        runner: runner,
      );

      expect(result.projectId, isNotNull);
      expect(result.domainMerged, 'quant');

      final pool = ExpertPool(poolDir);
      final domain = await pool.loadDomain('quant');
      expect(domain, isNotNull);
      expect(domain!.kind, ExpertKind.domain);
      expect(domain.domain, 'quant');
      expect(domain.meta.learnedProjectIds, contains(result.projectId));
      expect(domain.memory.projects.any((p) => p.id == result.projectId),
          isTrue);
      // distill output merged
      expect(domain.memory.notes, contains('quant abstraction'));
      expect(domain.memory.playbooks.any((p) => p.path == 'playbooks/quant.md'),
          isTrue);
    });

    test('merges into existing domain without duplicating learnedProjectIds',
        () async {
      final runner = FakeRunner(
        (dir, t) => '{}',
        distillResponder: (prompt) =>
            '{"domainNotes":"stable notes","playbooks":'
            '[{"path":"playbooks/shared.md","content":"shared"}]}',
      );

      // First publish — creates the domain.
      final r1 = await runPublish(
        options: PublishOptions(
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'experience-only',
          source: 'opensource',
          poolDir: poolDir,
          domain: 'quant',
          version: 1,
        ),
        runner: runner,
      );
      // Second publish of the same project — idempotent.
      final r2 = await runPublish(
        options: PublishOptions(
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'experience-only',
          source: 'opensource',
          poolDir: poolDir,
          domain: 'quant',
          version: 2,
        ),
        runner: runner,
      );

      expect(r1.projectId, r2.projectId);
      final pool = ExpertPool(poolDir);
      final domain = await pool.loadDomain('quant');
      expect(domain, isNotNull);
      // learnedProjectIds should still only contain the project once.
      final count =
          domain!.meta.learnedProjectIds.where((id) => id == r1.projectId).length;
      expect(count, 1);
      // playbooks deduped by path
      final pbCount = domain.memory.playbooks
          .where((p) => p.path == 'playbooks/shared.md')
          .length;
      expect(pbCount, 1);
    });
  });

  group('runPublish — none retention', () {
    test('returns PublishResult with null projectId and writes nothing', () async {
      final result = await runPublish(
        options: PublishOptions(
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'none',
          source: 'opensource',
          poolDir: poolDir,
          version: 1,
        ),
      );

      expect(result.projectId, isNull);
      expect(result.poolPath, isNull);
      expect(result.domainMerged, isNull);

      // Pool should be empty.
      final pool = ExpertPool(poolDir);
      final summaries = await pool.list();
      expect(summaries, isEmpty);
    });
  });

  group('runPublish — agent not found', () {
    test('throws ArgumentError when agent missing', () async {
      expect(
        () => runPublish(
          options: PublishOptions(
            agentName: 'no-such-agent',
            workspacePath: workspace.path,
            retention: 'full',
            source: 'private',
            poolDir: poolDir,
            version: 1,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
