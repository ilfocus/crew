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
    test('pool has agent + project; L1 specifics cleared, transferable kept',
        () async {
      final result = await runPublish(
        options: PublishOptions(
          agentId: 'ios-lin',
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'experience-only',
          source: 'opensource',
          poolDir: poolDir,
          version: 1,
        ),
      );

      expect(result.agentId, 'ios-lin');
      expect(result.projectId, isNotNull);
      expect(result.poolPath, isNotNull);
      expect(result.domainMerged, isNull);

      final pool = AgentPool(poolDir);

      // Agent profile saved
      final agent = await pool.load('ios-lin');
      expect(agent, isNotNull);
      expect(agent!.core.id, 'ios-lin');
      expect(agent.core.personality, '严谨');
      expect(agent.core.role, 'iOS 开发工程师');
      expect(agent.core.displayName, '小i');
      expect(agent.meta.version, 1);

      // Project saved with L1 specifics cleared (experience-only)
      final project = await pool.loadProject('ios-lin', result.projectId!);
      expect(project, isNotNull);
      expect(project!.keyFiles, isEmpty);
      expect(project.coordinates, '');
      expect(project.repos, isEmpty);
      expect(project.solved, isEmpty);
      // transferable fields preserved
      expect(project.techStack, ['Swift', 'SwiftUI']);
      expect(project.sdks, ['SensorsSDK']);
      expect(project.difficulties, ['线程安全']);
      expect(project.retention, 'experience-only');
      // paths redacted in notes
      expect(project.notes.contains('/Users/bm/app/ios'), isFalse);
    });
  });

  group('runPublish — full retention', () {
    test('preserves L1 specifics (keyFiles/coordinates/solved)', () async {
      final result = await runPublish(
        options: PublishOptions(
          agentId: 'ios-lin',
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'full',
          source: 'opensource',
          poolDir: poolDir,
          version: 1,
        ),
      );
      expect(result.projectId, isNotNull);

      final pool = AgentPool(poolDir);
      final project = await pool.loadProject('ios-lin', result.projectId!);
      expect(project, isNotNull);
      expect(project!.keyFiles.length, 1);
      expect(project.coordinates, '路径 ~/bm_app/ios');
      expect(project.solved.length, 1);
      expect(project.notes, 'L1 notes with /Users/bm/app/ios path');
      expect(project.retention, 'full');
    });
  });

  group('runPublish — with --to <domain>', () {
    test('creates domain, merges project; reverse index on both sides',
        () async {
      final runner = FakeRunner(
        (dir, t) => '{}',
        distillResponder: (prompt) =>
            '{"domainNotes":"iOS abstraction","playbooks":'
            '[{"path":"playbooks/leak.md","content":"steps"}]}',
      );

      final result = await runPublish(
        options: PublishOptions(
          agentId: 'ios-lin',
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'experience-only',
          source: 'opensource',
          poolDir: poolDir,
          domain: 'ios',
          version: 1,
        ),
        runner: runner,
      );

      expect(result.projectId, isNotNull);
      expect(result.domainMerged, 'ios');

      final pool = AgentPool(poolDir);

      // domain exists with distill output
      final domain = await pool.loadDomain('ios-lin', 'ios');
      expect(domain, isNotNull);
      expect(domain!.notes, contains('iOS abstraction'));
      expect(domain.playbooks.any((p) => p.path == 'playbooks/leak.md'), isTrue);
      // projects reference list has the project
      expect(domain.projects.any((p) => p.id == result.projectId), isTrue);

      // project reverse-index contains 'ios'
      final project = await pool.loadProject('ios-lin', result.projectId!);
      expect(project, isNotNull);
      expect(project!.domains, contains('ios'));
    });

    test('merges same project into second domain (multi-many)', () async {
      final runner = FakeRunner(
        (dir, t) => '{}',
        distillResponder: (prompt) =>
            '{"domainNotes":"shared","playbooks":[]}',
      );

      // First publish with --to ios
      final r1 = await runPublish(
        options: PublishOptions(
          agentId: 'ios-lin',
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'full',
          source: 'opensource',
          poolDir: poolDir,
          domain: 'ios',
          version: 1,
        ),
        runner: runner,
      );

      // Second publish with --to apm (same agentId, same projectId)
      final r2 = await runPublish(
        options: PublishOptions(
          agentId: 'ios-lin',
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'full',
          source: 'opensource',
          poolDir: poolDir,
          domain: 'apm',
          version: 1,
        ),
        runner: runner,
      );

      expect(r1.projectId, r2.projectId);

      final pool = AgentPool(poolDir);
      // project reverse-index has both domains
      final project = await pool.loadProject('ios-lin', r1.projectId!);
      expect(project, isNotNull);
      expect(project!.domains.toSet(), {'ios', 'apm'});

      // both domains reference the project
      final iosDomain = await pool.loadDomain('ios-lin', 'ios');
      final apmDomain = await pool.loadDomain('ios-lin', 'apm');
      expect(iosDomain!.projects.any((p) => p.id == r1.projectId), isTrue);
      expect(apmDomain!.projects.any((p) => p.id == r1.projectId), isTrue);
    });

    test('idempotent: re-publish same project to same domain', () async {
      final runner = FakeRunner(
        (dir, t) => '{}',
        distillResponder: (prompt) =>
            '{"domainNotes":"stable","playbooks":'
            '[{"path":"playbooks/shared.md","content":"x"}]}',
      );

      await runPublish(
        options: PublishOptions(
          agentId: 'ios-lin',
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'full',
          source: 'opensource',
          poolDir: poolDir,
          domain: 'ios',
          version: 1,
        ),
        runner: runner,
      );
      await runPublish(
        options: PublishOptions(
          agentId: 'ios-lin',
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'full',
          source: 'opensource',
          poolDir: poolDir,
          domain: 'ios',
          version: 2,
        ),
        runner: runner,
      );

      final pool = AgentPool(poolDir);
      final domain = await pool.loadDomain('ios-lin', 'ios');
      expect(domain, isNotNull);
      // projects not duplicated
      expect(domain!.projects.length, 1);
      // playbooks deduped by path
      final pbCount = domain.playbooks
          .where((p) => p.path == 'playbooks/shared.md')
          .length;
      expect(pbCount, 1);
    });
  });

  group('runPublish — none retention', () {
    test('returns empty result, writes nothing to pool', () async {
      final result = await runPublish(
        options: PublishOptions(
          agentId: 'ios-lin',
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'none',
          source: 'opensource',
          poolDir: poolDir,
          version: 1,
        ),
      );

      expect(result.agentId, isNull);
      expect(result.projectId, isNull);
      expect(result.poolPath, isNull);
      expect(result.domainMerged, isNull);

      // Pool should be empty.
      final pool = AgentPool(poolDir);
      final summaries = await pool.list();
      expect(summaries, isEmpty);
    });
  });

  group('runPublish — agent not found', () {
    test('throws ArgumentError when agent missing', () async {
      expect(
        () => runPublish(
          options: PublishOptions(
            agentId: 'ios-lin',
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

  group('runPublish — preserves existing memory', () {
    test('re-publish preserves pre-existing short-term memory', () async {
      final pool = AgentPool(poolDir);
      // Pre-create an agent with short-term memory
      await pool.save(AgentProfile(
        core: AgentCore(
          id: 'ios-lin',
          name: 'ios',
          displayName: '小i',
          role: 'iOS',
        ),
        memory: const AgentMemory(
          index: '# OLD INDEX',
          shortTerm: 'old short-term line',
          longTerm: [MemoryEntry('long-term/old.md', 'old')],
        ),
        meta: const AgentMeta(version: 1),
      ));

      // Re-publish
      await runPublish(
        options: PublishOptions(
          agentId: 'ios-lin',
          agentName: 'ios',
          workspacePath: workspace.path,
          retention: 'full',
          source: 'opensource',
          poolDir: poolDir,
          version: 2,
        ),
      );

      // Memory preserved (version bumped to 2)
      final agent = await pool.load('ios-lin');
      expect(agent, isNotNull);
      expect(agent!.meta.version, 2);
      expect(agent.memory.shortTerm, 'old short-term line');
      expect(agent.memory.longTerm.length, 1);
      expect(agent.memory.longTerm.first.path, 'long-term/old.md');
    });
  });
}
