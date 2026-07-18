// crew_cli/test/migrate_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:crew_cli/src/commands/migrate.dart';
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
}) {
  return Expert(
    kind: ExpertKind.project,
    spec: AgentSpec(
      name: name,
      displayName: displayName,
      repos: const ['~/bm_app/ios'],
      role: role,
      coordinates: '路径',
      moduleStructure: 'Core/',
      keyFiles: const [KeyFile('Core/Foo.swift:1', '上报')],
      dataflow: '',
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
  String domain = 'ios',
  String personality = '严谨',
}) {
  return Expert(
    kind: ExpertKind.domain,
    domain: domain,
    spec: AgentSpec(
      name: name,
      displayName: 'iOS 领域专家',
      repos: const [],
      role: 'iOS 领域工程师',
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
      notes: 'L2 notes',
      playbooks: [MemoryEntry('playbooks/d.md', '步骤')],
      projects: [ProjectRef('github.com/foo/bar', 'iOS APM')],
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
  late Directory poolDir;

  setUp(() async {
    poolDir = await Directory.systemTemp.createTemp('cli_migrate_');
  });

  tearDown(() async {
    if (poolDir.existsSync()) await poolDir.delete(recursive: true);
    final bak = Directory('${poolDir.path}.bak');
    if (bak.existsSync()) await bak.delete(recursive: true);
  });

  group('runMigrate — first run', () {
    test('migrates old layout, creates backup, deletes old subdirs', () async {
      _writeExpert(poolDir, _projectExpert(name: 'ios', projectId: 'p1'));
      _writeExpert(poolDir, _domainExpert(name: 'ios', domain: 'ios'));

      final result = await runMigrate(
        options: MigrateOptions(poolDir: poolDir, version: 1),
      );

      // Report
      expect(result.report.agents, 1);
      expect(result.report.projectsMoved, 1);
      expect(result.report.domainsMoved, 1);
      expect(result.report.needsManualReview, isEmpty);

      // Backup created
      expect(result.backupPath, isNotNull);
      final bak = Directory(result.backupPath!);
      expect(bak.existsSync(), isTrue);
      // Backup has old layout
      expect(File('${bak.path}/projects/p1/expert.json').existsSync(), isTrue);
      expect(File('${bak.path}/domains/ios/expert.json').existsSync(), isTrue);

      // Pool dir has new layout
      expect(File('${poolDir.path}/agents/ios/agent.json').existsSync(), isTrue);
      expect(
          File('${poolDir.path}/agents/ios/projects/p1/project.json')
              .existsSync(),
          isTrue);
      expect(
          File('${poolDir.path}/agents/ios/domains/ios/domain.json')
              .existsSync(),
          isTrue);

      // Old layout deleted from pool
      expect(Directory('${poolDir.path}/projects').existsSync(), isFalse);
      expect(Directory('${poolDir.path}/domains').existsSync(), isFalse);
    });

    test('multi-agent migration with conflict reported', () async {
      _writeExpert(poolDir,
          _projectExpert(name: 'ios', projectId: 'p1', personality: '严谨'));
      _writeExpert(poolDir,
          _projectExpert(name: 'ios', projectId: 'p2', personality: '随意'));
      _writeExpert(poolDir, _domainExpert(name: 'android', domain: 'android'));

      final result = await runMigrate(
        options: MigrateOptions(poolDir: poolDir, version: 1),
      );

      expect(result.report.agents, 2);
      expect(result.report.projectsMoved, 2);
      expect(result.report.domainsMoved, 1);
      expect(result.report.needsManualReview.length, 1);
      expect(result.report.needsManualReview.first, contains('ios'));
    });
  });

  group('runMigrate — idempotency', () {
    test('run twice produces same result; backup not recreated', () async {
      _writeExpert(poolDir, _projectExpert(name: 'ios', projectId: 'p1'));
      _writeExpert(poolDir, _domainExpert(name: 'ios', domain: 'ios'));

      final r1 = await runMigrate(
        options: MigrateOptions(poolDir: poolDir, version: 1),
      );
      final r2 = await runMigrate(
        options: MigrateOptions(poolDir: poolDir, version: 1),
      );

      // Counts match
      expect(r2.report.agents, r1.report.agents);
      expect(r2.report.projectsMoved, r1.report.projectsMoved);
      expect(r2.report.domainsMoved, r1.report.domainsMoved);

      // First run created backup; second run did not (backup preserved)
      expect(r1.backupPath, isNotNull);
      expect(r2.backupPath, isNull);

      // Pool still has new layout (not duplicated, not deleted)
      expect(File('${poolDir.path}/agents/ios/agent.json').existsSync(), isTrue);
      final pool = AgentPool(poolDir);
      final agent = await pool.load('ios');
      expect(agent, isNotNull);
      expect(agent!.projects.length, 1);
      expect(agent.domains.length, 1);
    });
  });

  group('runMigrate — edge cases', () {
    test('empty pool is no-op, no backup created', () async {
      final result = await runMigrate(
        options: MigrateOptions(poolDir: poolDir, version: 1),
      );
      expect(result.report.agents, 0);
      expect(result.report.projectsMoved, 0);
      expect(result.report.domainsMoved, 0);
      expect(result.backupPath, isNull);
      expect(Directory('${poolDir.path}.bak').existsSync(), isFalse);
    });

    test('pool with only agents/ (already migrated) is no-op', () async {
      // Pre-populate with new layout only
      final pool = AgentPool(poolDir);
      await pool.save(AgentProfile(
        core: AgentCore(
          id: 'ios',
          name: 'ios',
          displayName: 'iOS',
          role: 'iOS',
        ),
        meta: const AgentMeta(version: 1),
      ));

      final result = await runMigrate(
        options: MigrateOptions(poolDir: poolDir, version: 1),
      );
      expect(result.report.agents, 0);
      expect(result.backupPath, isNull);
      // agents/ untouched
      expect(File('${poolDir.path}/agents/ios/agent.json').existsSync(), isTrue);
    });
  });
}
