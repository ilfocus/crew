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
      AgentPool(poolDir),
      runnerFactory: () => FakeRunner(
        (dir, t) => '{}',
        distillResponder: (prompt) =>
            '{"domainNotes":"L2 distilled","playbooks":'
            '[{"path":"playbooks/release.md","content":"steps"}]}',
      ),
    );
  });

  tearDown(() {
    poolDir.deleteSync(recursive: true);
    workspaceDir.deleteSync(recursive: true);
  });

  group('publish', () {
    test('experience-only + domain: agent + project + domain saved', () async {
      final outcome = await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'experience-only',
        source: 'opensource',
        domain: 'quant',
        version: 1,
      );
      expect(outcome.isSuccess, isTrue);
      expect(outcome.agentId, 'ios-lin');
      expect(outcome.projectId, isNotNull);
      expect(outcome.domainMerged, 'quant');

      final pool = AgentPool(poolDir);

      // Agent saved with core
      final agent = await pool.load('ios-lin');
      expect(agent, isNotNull);
      expect(agent!.core.id, 'ios-lin');
      expect(agent.core.role, 'iOS 开发工程师');
      expect(agent.core.personality, '严谨');
      expect(agent.meta.version, 1);

      // Project saved with L1 specifics cleared (experience-only)
      final project = await pool.loadProject('ios-lin', outcome.projectId!);
      expect(project, isNotNull);
      expect(project!.keyFiles, isEmpty);
      expect(project.coordinates, '');
      expect(project.solved, isEmpty);
      expect(project.retention, 'experience-only');
      // transferable preserved
      expect(project.techStack, ['Swift', 'SwiftUI']);

      // Domain saved with projects ref
      final domain = await pool.loadDomain('ios-lin', 'quant');
      expect(domain, isNotNull);
      expect(domain!.projects.any((p) => p.id == outcome.projectId), isTrue);

      // project reverse-index contains 'quant'
      expect(project.domains, contains('quant'));

      // list returns 1 agent summary with the domain
      final list = await service.list();
      expect(list.length, 1);
      expect(list.first.id, 'ios-lin');
      expect(list.first.domains, contains('quant'));
      expect(list.first.projectCount, 1);
    });

    test('full retention preserves L1 specifics', () async {
      final outcome = await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'full',
        source: 'opensource',
        version: 1,
      );
      expect(outcome.isSuccess, isTrue);

      final pool = AgentPool(poolDir);
      final project = await pool.loadProject('ios-lin', outcome.projectId!);
      expect(project, isNotNull);
      expect(project!.keyFiles.length, 1);
      expect(project.coordinates, '路径 ~/proj/ios');
      expect(project.solved.length, 1);
      expect(project.retention, 'full');
    });

    test('none retention returns null projectId, writes nothing', () async {
      final outcome = await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'none',
        source: 'opensource',
        version: 1,
      );
      expect(outcome.isSuccess, isTrue);
      expect(outcome.agentId, isNull);
      expect(outcome.projectId, isNull);

      final list = await service.list();
      expect(list, isEmpty);
    });

    test('multi-many: re-publish with --to <other-domain> accumulates reverse index',
        () async {
      // First publish to 'quant'
      final r1 = await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'full',
        source: 'opensource',
        domain: 'quant',
        version: 1,
      );
      // Second publish to 'apm' (same project, different domain)
      final r2 = await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'full',
        source: 'opensource',
        domain: 'apm',
        version: 1,
      );
      expect(r1.projectId, r2.projectId);

      final pool = AgentPool(poolDir);
      final project = await pool.loadProject('ios-lin', r1.projectId!);
      expect(project, isNotNull);
      expect(project!.domains.toSet(), {'quant', 'apm'});

      // Both domains reference the project
      final quant = await pool.loadDomain('ios-lin', 'quant');
      final apm = await pool.loadDomain('ios-lin', 'apm');
      expect(quant!.projects.any((p) => p.id == r1.projectId), isTrue);
      expect(apm!.projects.any((p) => p.id == r1.projectId), isTrue);
    });

    test('re-publish preserves existing short-term memory', () async {
      final pool = AgentPool(poolDir);
      // Pre-create an agent with short-term memory
      await pool.save(AgentProfile(
        core: const AgentCore(
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

      await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'full',
        source: 'opensource',
        version: 2,
      );

      final agent = await pool.load('ios-lin');
      expect(agent, isNotNull);
      expect(agent!.meta.version, 2);
      expect(agent.memory.shortTerm, 'old short-term line');
      expect(agent.memory.longTerm.length, 1);
      expect(agent.memory.longTerm.first.path, 'long-term/old.md');
    });

    test('agent not found returns error', () async {
      final outcome = await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'no-such-agent',
        retention: 'full',
        source: 'opensource',
        version: 1,
      );
      expect(outcome.isSuccess, isFalse);
      expect(outcome.error, contains('not found'));
    });
  });

  group('useExpert', () {
    test('writes memory files without solved/', () async {
      // First publish to create the agent + domain
      await service.publish(
        agentId: 'ios-lin',
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
        agentId: 'ios-lin',
        domain: 'quant',
        intoPath: targetDir.path,
        agentName: 'ios-new',
        repos: ['~/newproj/ios'],
      );
      expect(outcome.isSuccess, isTrue);
      expect(outcome.writtenPaths, isNotEmpty);

      // domain-notes.md exists (L2)
      expect(
        File('${targetDir.path}/memory/ios-new/domain-notes.md').existsSync(),
        isTrue,
      );
      // playbooks/ directory exists
      expect(
        Directory('${targetDir.path}/memory/ios-new/playbooks').existsSync(),
        isTrue,
      );
      // solved/ directory does NOT exist
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

    test('non-existent agent returns error', () async {
      final outcome = await service.useExpert(
        agentId: 'no-such-agent',
        domain: 'quant',
        intoPath: '/tmp/whatever',
        agentName: 'x',
        repos: [],
      );
      expect(outcome.isSuccess, isFalse);
      expect(outcome.error, contains('not found'));
    });

    test('non-existent domain for existing agent returns error', () async {
      // First publish the agent (no domain)
      await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'full',
        source: 'opensource',
        version: 1,
      );

      final outcome = await service.useExpert(
        agentId: 'ios-lin',
        domain: 'no-such-domain',
        intoPath: '/tmp/whatever',
        agentName: 'x',
        repos: [],
      );
      expect(outcome.isSuccess, isFalse);
      expect(outcome.error, contains('not found'));
    });

    test('preserves existing memory files (isMemory protection)', () async {
      await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'experience-only',
        source: 'opensource',
        domain: 'quant',
        version: 1,
      );

      final targetDir = Directory.systemTemp.createTempSync('target');
      addTearDown(() => targetDir.deleteSync(recursive: true));

      // Pre-create MEMORY.md with user content
      final memFile = File('${targetDir.path}/memory/ios-new/MEMORY.md');
      memFile.parent.createSync(recursive: true);
      const userContent = 'user hand-written';
      memFile.writeAsStringSync(userContent);

      await service.useExpert(
        agentId: 'ios-lin',
        domain: 'quant',
        intoPath: targetDir.path,
        agentName: 'ios-new',
        repos: [],
      );

      // Existing memory file preserved
      expect(memFile.readAsStringSync(), userContent);
    });
  });

  group('delete', () {
    test('deleteAgent removes the entire agent directory', () async {
      await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'full',
        source: 'opensource',
        domain: 'quant',
        version: 1,
      );

      await service.deleteAgent('ios-lin');

      final pool = AgentPool(poolDir);
      expect(await pool.load('ios-lin'), isNull);
      expect(await pool.list(), isEmpty);
      // agent dir gone
      expect(
        Directory('${poolDir.path}/agents/ios-lin').existsSync(),
        isFalse,
      );
    });

    test('deleteDomain removes only the sub-domain', () async {
      await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'full',
        source: 'opensource',
        domain: 'quant',
        version: 1,
      );
      await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'full',
        source: 'opensource',
        domain: 'apm',
        version: 1,
      );

      await service.deleteDomain('ios-lin', 'quant');

      final pool = AgentPool(poolDir);
      // agent still there
      expect(await pool.load('ios-lin'), isNotNull);
      // apm domain still there
      expect(await pool.loadDomain('ios-lin', 'apm'), isNotNull);
      // quant domain gone
      expect(await pool.loadDomain('ios-lin', 'quant'), isNull);
    });

    test('deleteProject removes only the sub-project', () async {
      final r = await service.publish(
        agentId: 'ios-lin',
        workspacePath: workspaceDir.path,
        agentName: 'ios',
        retention: 'full',
        source: 'opensource',
        version: 1,
      );

      await service.deleteProject('ios-lin', r.projectId!);

      final pool = AgentPool(poolDir);
      // agent still there
      expect(await pool.load('ios-lin'), isNotNull);
      // project gone
      expect(await pool.loadProject('ios-lin', r.projectId!), isNull);
    });
  });

  group('migrate', () {
    test('migrates old flat layout to new agent hierarchy with backup',
        () async {
      // Build old layout: <pool>/projects/<id>/expert.json + domains/<d>/expert.json
      final oldProjDir =
          Directory('${poolDir.path}/projects/github.com/foo/bar')
            ..createSync(recursive: true);
      File('${oldProjDir.path}/expert.json').writeAsStringSync(jsonEncode(
        Expert(
          kind: ExpertKind.project,
          spec: const AgentSpec(
            name: 'ios',
            displayName: '小i',
            repos: [],
            role: 'iOS 开发工程师',
            coordinates: '',
            moduleStructure: '',
            keyFiles: [],
            dataflow: '',
            memoryConvention: '',
            conventions: [],
            personality: '严谨',
            principles: [],
            techStack: [],
            sdks: [],
            difficulties: [],
            source: 'opensource',
            github: '',
          ),
          memory: const ExpertMemory(),
          meta: const ExpertMeta(
            projectId: 'github.com/foo/bar',
            version: 1,
          ),
        ).toJson(),
      ));

      final outcome = await service.migrate(version: 1);

      expect(outcome.isSuccess, isTrue);
      expect(outcome.agents, 1);
      expect(outcome.projectsMoved, 1);
      expect(outcome.backupPath, isNotNull);
      expect(outcome.backupPath, '${poolDir.path}.bak');

      // New layout exists
      final pool = AgentPool(poolDir);
      final agent = await pool.load('ios');
      expect(agent, isNotNull);
      expect(agent!.core.id, 'ios');

      // backup exists
      expect(Directory('${poolDir.path}.bak').existsSync(), isTrue);

      // old subdirs gone
      expect(Directory('${poolDir.path}/projects').existsSync(), isFalse);
      expect(Directory('${poolDir.path}/domains').existsSync(), isFalse);
    });

    test('idempotent: second run does not recreate backup', () async {
      final oldProjDir =
          Directory('${poolDir.path}/projects/github.com/foo/bar')
            ..createSync(recursive: true);
      File('${oldProjDir.path}/expert.json').writeAsStringSync(jsonEncode(
        Expert(
          kind: ExpertKind.project,
          spec: const AgentSpec(
            name: 'ios',
            displayName: '小i',
            repos: [],
            role: 'iOS',
            coordinates: '',
            moduleStructure: '',
            keyFiles: [],
            dataflow: '',
            memoryConvention: '',
            conventions: [],
            personality: '严谨',
            principles: [],
            techStack: [],
            sdks: [],
            difficulties: [],
          ),
          memory: const ExpertMemory(),
          meta: const ExpertMeta(
            projectId: 'github.com/foo/bar',
            version: 1,
          ),
        ).toJson(),
      ));

      final r1 = await service.migrate(version: 1);
      expect(r1.backupPath, isNotNull);

      final r2 = await service.migrate(version: 1);
      expect(r2.isSuccess, isTrue);
      expect(r2.backupPath, isNull);
    });

    test('already-migrated pool returns empty report', () async {
      // Just an agents/ dir, no old layout
      Directory('${poolDir.path}/agents').createSync(recursive: true);

      final outcome = await service.migrate(version: 1);
      expect(outcome.isSuccess, isTrue);
      expect(outcome.agents, 0);
      expect(outcome.backupPath, isNull);
    });
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
