// crew_core/test/expert/migrate_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:crew_core/crew_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void _writeExpert(Directory root, Expert e) {
  late final String kindDir;
  late final String id;
  if (e.kind == ExpertKind.project) {
    kindDir = 'projects';
    id = e.meta.projectId;
  } else {
    kindDir = 'domains';
    id = e.domain;
  }
  final dir = Directory(p.join(root.path, kindDir, id));
  dir.createSync(recursive: true);
  File(p.join(dir.path, 'expert.json'))
      .writeAsStringSync(jsonEncode(e.toJson()));
}

Expert _projectExpert({
  String name = 'ios',
  String displayName = '小i',
  String personality = '严谨',
  String projectId = 'github.com/foo/bar',
  String role = 'iOS 开发工程师',
  String domain = '',
}) {
  return Expert(
    kind: ExpertKind.project,
    domain: domain,
    spec: AgentSpec(
      name: name,
      displayName: displayName,
      repos: ['~/bm_app/ios'],
      role: role,
      coordinates: '路径 ~/bm_app/ios',
      moduleStructure: 'Core/ 单例',
      keyFiles: const [KeyFile('Core/Foo.swift:279', '上报总线')],
      dataflow: '采集 → 神策',
      memoryConvention: '',
      conventions: const [],
      personality: personality,
      principles: const ['不引入未测试依赖'],
      techStack: const ['Swift'],
      source: 'opensource',
      github: 'https://github.com/foo/bar.git',
    ),
    memory: const ExpertMemory(
      notes: 'L1 notes',
      solved: [MemoryEntry('solved/x.md', 'fix X')],
      playbooks: [MemoryEntry('playbooks/y.md', '步骤')],
    ),
    meta: ExpertMeta(
      source: 'opensource',
      github: 'https://github.com/foo/bar.git',
      retention: 'full',
      projectId: projectId,
      version: 1,
    ),
  );
}

Expert _domainExpert({
  String name = 'ios',
  String displayName = 'iOS 领域专家',
  String personality = '严谨',
  String domain = 'ios',
  String role = 'iOS 领域工程师',
}) {
  return Expert(
    kind: ExpertKind.domain,
    domain: domain,
    spec: AgentSpec(
      name: name,
      displayName: displayName,
      repos: const [],
      role: role,
      coordinates: '',
      moduleStructure: '',
      keyFiles: const [],
      dataflow: '',
      memoryConvention: '',
      conventions: const [],
      personality: personality,
      principles: const ['不引入未测试依赖'],
      techStack: const ['Swift'],
    ),
    memory: const ExpertMemory(
      index: '# DOMAIN MEMORY',
      notes: 'L2 domain notes',
      playbooks: [MemoryEntry('playbooks/d-x.md', '步骤')],
      projects: [ProjectRef('github.com/foo/bar', 'iOS APM SDK')],
    ),
    meta: const ExpertMeta(
      source: 'opensource',
      retention: 'experience-only',
      learnedProjectIds: ['github.com/foo/bar'],
      version: 1,
    ),
  );
}

void main() {
  late Directory oldRoot;
  late Directory newRoot;

  setUp(() async {
    final tmp = await Directory.systemTemp.createTemp('migrate_test_');
    oldRoot = Directory(p.join(tmp.path, 'old'));
    newRoot = Directory(p.join(tmp.path, 'new'));
    await oldRoot.create(recursive: true);
    await newRoot.create(recursive: true);
  });

  tearDown(() async {
    if (oldRoot.parent.existsSync()) {
      await oldRoot.parent.delete(recursive: true);
    }
  });

  group('migratePool — basic migration', () {
    test('2 projects + 1 domain with same name → 1 agent', () async {
      _writeExpert(oldRoot, _projectExpert(
        name: 'ios',
        projectId: 'github.com/foo/bar',
      ));
      _writeExpert(oldRoot, _projectExpert(
        name: 'ios',
        projectId: 'github.com/x/y',
        displayName: '小i (y)',
      ));
      _writeExpert(oldRoot, _domainExpert(name: 'ios', domain: 'ios'));

      final report = await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 2,
      );

      expect(report.agents, 1);
      expect(report.projectsMoved, 2);
      expect(report.domainsMoved, 1);
      expect(report.needsManualReview, isEmpty);

      // 验证新布局
      final pool = AgentPool(newRoot);
      final agent = await pool.load('ios');
      expect(agent, isNotNull);
      expect(agent!.core.name, 'ios');
      expect(agent.core.personality, '严谨');
      expect(agent.core.role, 'iOS 开发工程师');
      expect(agent.domains.length, 1);
      expect(agent.domains.first.domain, 'ios');
      expect(agent.projects.length, 2);
      expect(agent.meta.version, 2);

      // 验证 projects 反向索引（domain names）
      final p1 = await pool.loadProject('ios', 'github.com/foo/bar');
      expect(p1, isNotNull);
      expect(p1!.domains, contains('ios'));

      // 验证 domain.notes 搬入
      final d = await pool.loadDomain('ios', 'ios');
      expect(d, isNotNull);
      expect(d!.notes, contains('L2 domain notes'));
      expect(d.projects.length, 1); // learnedProjectIds 映射到 projects ref
      expect(d.projects.first.id, 'github.com/foo/bar');
    });

    test('agents with different names → multiple agents', () async {
      _writeExpert(oldRoot, _projectExpert(name: 'ios', projectId: 'p1'));
      _writeExpert(oldRoot, _projectExpert(name: 'android', projectId: 'p2'));

      final report = await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );

      expect(report.agents, 2);
      expect(report.projectsMoved, 2);
      expect(report.domainsMoved, 0);

      final pool = AgentPool(newRoot);
      final ios = await pool.load('ios');
      final android = await pool.load('android');
      expect(ios, isNotNull);
      expect(android, isNotNull);
      expect(ios!.core.id, 'ios');
      expect(android!.core.id, 'android');
    });

    test('project-only (no domain) → empty domains reverse index', () async {
      _writeExpert(oldRoot, _projectExpert(name: 'ios', projectId: 'p1'));

      final report = await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );
      expect(report.agents, 1);
      expect(report.domainsMoved, 0);

      final pool = AgentPool(newRoot);
      final p1 = await pool.loadProject('ios', 'p1');
      expect(p1, isNotNull);
      expect(p1!.domains, isEmpty);
    });

    test('domain-only (no projects) → no projects, agent still saved', () async {
      _writeExpert(oldRoot, _domainExpert(name: 'ios', domain: 'ios'));

      final report = await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );
      expect(report.agents, 1);
      expect(report.domainsMoved, 1);
      expect(report.projectsMoved, 0);

      final pool = AgentPool(newRoot);
      final agent = await pool.load('ios');
      expect(agent, isNotNull);
      expect(agent!.domains.length, 1);
      expect(agent.projects, isEmpty);
    });
  });

  group('migratePool — idempotency', () {
    test('run twice produces same result', () async {
      _writeExpert(oldRoot, _projectExpert(name: 'ios', projectId: 'p1'));
      _writeExpert(oldRoot, _domainExpert(name: 'ios', domain: 'ios'));

      final r1 = await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );
      final r2 = await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );

      expect(r2.agents, r1.agents);
      expect(r2.projectsMoved, r1.projectsMoved);
      expect(r2.domainsMoved, r1.domainsMoved);
      expect(r2.needsManualReview, r1.needsManualReview);

      final pool = AgentPool(newRoot);
      final agent = await pool.load('ios');
      expect(agent, isNotNull);
      expect(agent!.projects.length, 1); // not duplicated
      expect(agent.domains.length, 1); // not duplicated
    });
  });

  group('migratePool — personality conflict', () {
    test('different personalities for same name → needsManualReview', () async {
      _writeExpert(oldRoot, _projectExpert(
        name: 'ios',
        projectId: 'p1',
        personality: '严谨',
      ));
      _writeExpert(oldRoot, _projectExpert(
        name: 'ios',
        projectId: 'p2',
        personality: '随意', // conflict!
      ));

      final report = await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );

      expect(report.agents, 1);
      expect(report.needsManualReview, isNotEmpty);
      expect(report.needsManualReview.first, contains('ios'));
    });

    test('empty personality does not conflict with non-empty', () async {
      _writeExpert(oldRoot, _projectExpert(
        name: 'ios',
        projectId: 'p1',
        personality: '严谨',
      ));
      _writeExpert(oldRoot, _projectExpert(
        name: 'ios',
        projectId: 'p2',
        personality: '', // empty — does not conflict
      ));

      final report = await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );
      expect(report.needsManualReview, isEmpty);
    });

    test('multiple non-empty personalities all listed in review', () async {
      _writeExpert(oldRoot, _projectExpert(
        name: 'ios',
        projectId: 'p1',
        personality: 'A',
      ));
      _writeExpert(oldRoot, _projectExpert(
        name: 'ios',
        projectId: 'p2',
        personality: 'B',
      ));
      _writeExpert(oldRoot, _projectExpert(
        name: 'ios',
        projectId: 'p3',
        personality: 'C',
      ));

      final report = await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );
      expect(report.needsManualReview.length, 1);
      final msg = report.needsManualReview.first;
      expect(msg, contains('A'));
      expect(msg, contains('B'));
      expect(msg, contains('C'));
    });
  });

  group('migratePool — empty / missing old root', () {
    test('empty old root → 0 agents, no error', () async {
      final report = await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );
      expect(report.agents, 0);
      expect(report.projectsMoved, 0);
      expect(report.domainsMoved, 0);
      expect(report.needsManualReview, isEmpty);
    });

    test('missing old root → 0 agents, no error', () async {
      final missingRoot = Directory(p.join(oldRoot.path, 'does-not-exist'));
      final report = await migratePool(
        oldRoot: missingRoot,
        newRoot: newRoot,
        version: 1,
      );
      expect(report.agents, 0);
    });
  });

  group('migratePool — field mapping', () {
    test('project expert L1 memory carried over', () async {
      _writeExpert(oldRoot, _projectExpert(name: 'ios', projectId: 'p1'));

      await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );

      final pool = AgentPool(newRoot);
      final p1 = await pool.loadProject('ios', 'p1');
      expect(p1, isNotNull);
      expect(p1!.notes, 'L1 notes');
      expect(p1.solved.length, 1);
      expect(p1.solved.first.path, 'solved/x.md');
      expect(p1.playbooks.length, 1);
      expect(p1.playbooks.first.path, 'playbooks/y.md');
    });

    test('project expert spec fields mapped to ProjectCompetence', () async {
      _writeExpert(oldRoot, _projectExpert(name: 'ios', projectId: 'p1'));

      await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );

      final pool = AgentPool(newRoot);
      final p1 = await pool.loadProject('ios', 'p1');
      expect(p1, isNotNull);
      expect(p1!.repos, ['~/bm_app/ios']);
      expect(p1.coordinates, '路径 ~/bm_app/ios');
      expect(p1.moduleStructure, 'Core/ 单例');
      expect(p1.keyFiles.length, 1);
      expect(p1.keyFiles.first.path, 'Core/Foo.swift:279');
      expect(p1.techStack, ['Swift']);
      expect(p1.source, 'opensource');
      expect(p1.retention, 'full');
    });

    test('domain expert notes/playbooks carried over', () async {
      _writeExpert(oldRoot, _domainExpert(name: 'ios', domain: 'ios'));

      await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );

      final pool = AgentPool(newRoot);
      final d = await pool.loadDomain('ios', 'ios');
      expect(d, isNotNull);
      expect(d!.notes, 'L2 domain notes');
      expect(d.playbooks.length, 1);
      expect(d.playbooks.first.path, 'playbooks/d-x.md');
    });

    test('core assembled from canonical spec (first with personality)', () async {
      _writeExpert(oldRoot, _projectExpert(
        name: 'ios',
        projectId: 'p1',
        personality: '', // empty
        role: 'iOS 工程师',
        displayName: '小i',
      ));
      _writeExpert(oldRoot, _domainExpert(
        name: 'ios',
        domain: 'ios',
        personality: '严谨',
        role: 'iOS 领域工程师',
        displayName: 'iOS 领域专家',
      ));

      await migratePool(
        oldRoot: oldRoot,
        newRoot: newRoot,
        version: 1,
      );

      final pool = AgentPool(newRoot);
      final agent = await pool.load('ios');
      expect(agent, isNotNull);
      // canonical: domain expert (has non-empty personality)
      expect(agent!.core.personality, '严谨');
      expect(agent.core.role, 'iOS 领域工程师');
      expect(agent.core.displayName, 'iOS 领域专家');
    });
  });
}
