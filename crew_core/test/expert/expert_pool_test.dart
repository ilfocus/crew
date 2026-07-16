// crew_core/test/expert/expert_pool_test.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late ExpertPool pool;

  setUp(() {
    root = Directory.systemTemp.createTempSync('expert_pool');
    pool = ExpertPool(root);
  });
  tearDown(() => root.deleteSync(recursive: true));

  AgentSpec spec(String name, {String displayName = 'D'}) => AgentSpec(
        name: name,
        displayName: displayName,
        repos: const [],
        role: 'role',
        coordinates: '',
        moduleStructure: '',
        keyFiles: const [],
        dataflow: '',
        memoryConvention: '',
        conventions: const [],
        personality: '',
        principles: const [],
        techStack: const [],
        sdks: const [],
        difficulties: const [],
        source: 'private',
        github: '',
      );

  group('saveProject / loadProject round-trip', () {
    test('project expert survives save → load', () async {
      final expert = Expert(
        kind: ExpertKind.project,
        spec: spec('ios', displayName: '小i'),
        memory: const ExpertMemory(
          index: '# MEMORY',
          notes: 'L1 notes',
          solved: [MemoryEntry('crash.md', 'fix crash')],
          playbooks: [MemoryEntry('release.md', 'release steps')],
        ),
        meta: const ExpertMeta(
          projectId: 'github.com/foo/bar',
          version: 3,
        ),
      );

      await pool.saveProject(expert);
      final loaded = await pool.loadProject('github.com/foo/bar');

      expect(loaded, isNotNull);
      expect(loaded!.kind, ExpertKind.project);
      expect(loaded.spec.name, 'ios');
      expect(loaded.spec.displayName, '小i');
      expect(loaded.memory.index, '# MEMORY');
      expect(loaded.memory.notes, 'L1 notes');
      expect(loaded.memory.solved.length, 1);
      expect(loaded.memory.solved.first.path, 'crash.md');
      expect(loaded.memory.solved.first.content, 'fix crash');
      expect(loaded.memory.playbooks.length, 1);
      expect(loaded.meta.projectId, 'github.com/foo/bar');
      expect(loaded.meta.version, 3);
    });

    test('human-readable files are written alongside expert.json', () async {
      final expert = Expert(
        kind: ExpertKind.project,
        spec: spec('ios', displayName: '小i'),
        memory: const ExpertMemory(index: '# M', notes: 'notes'),
        meta: const ExpertMeta(projectId: 'github.com/foo/bar'),
      );
      await pool.saveProject(expert);

      final dir = '${root.path}/projects/github.com/foo/bar';
      expect(File('$dir/expert.json').existsSync(), isTrue);
      expect(File('$dir/IDENTITY.md').existsSync(), isTrue);
      expect(File('$dir/COMPETENCE.md').existsSync(), isTrue);
      expect(File('$dir/memory/MEMORY.md').existsSync(), isTrue);
      expect(File('$dir/memory/project-notes.md').existsSync(), isTrue);
    });
  });

  group('saveDomain / loadDomain round-trip', () {
    test('domain expert survives save → load', () async {
      final expert = Expert(
        kind: ExpertKind.domain,
        domain: 'ios',
        spec: spec('ios-domain', displayName: 'iOS 领域专家'),
        memory: const ExpertMemory(
          notes: 'L2 notes',
          projects: [ProjectRef('github.com/foo/bar', 'APM SDK')],
        ),
        meta: const ExpertMeta(
          version: 1,
          learnedProjectIds: ['github.com/foo/bar'],
        ),
      );

      await pool.saveDomain(expert);
      final loaded = await pool.loadDomain('ios');

      expect(loaded, isNotNull);
      expect(loaded!.kind, ExpertKind.domain);
      expect(loaded.domain, 'ios');
      expect(loaded.spec.displayName, 'iOS 领域专家');
      expect(loaded.memory.notes, 'L2 notes');
      expect(loaded.memory.projects.length, 1);
      expect(loaded.memory.projects.first.id, 'github.com/foo/bar');
      expect(loaded.memory.projects.first.summary, 'APM SDK');
    });

    test('domain-only files are written', () async {
      final expert = Expert(
        kind: ExpertKind.domain,
        domain: 'ios',
        spec: spec('ios-domain'),
        memory: const ExpertMemory(
          notes: 'L2',
          projects: [ProjectRef('github.com/foo/bar', 'APM')],
        ),
        meta: const ExpertMeta(),
      );
      await pool.saveDomain(expert);

      final dir = '${root.path}/domains/ios';
      expect(File('$dir/memory/domain-notes.md').existsSync(), isTrue);
      expect(File('$dir/memory/projects.md').existsSync(), isTrue);
      // Project-only file should NOT exist
      expect(File('$dir/memory/project-notes.md').existsSync(), isFalse);
    });
  });

  group('list()', () {
    test('returns empty list when root does not exist', () async {
      final deadPool = ExpertPool(Directory('${root.path}/nope'));
      expect(await deadPool.list(), isEmpty);
    });

    test('returns correct summaries after saving project + domain', () async {
      final proj = Expert(
        kind: ExpertKind.project,
        spec: spec('ios', displayName: '小i'),
        memory: const ExpertMemory(),
        meta: const ExpertMeta(projectId: 'github.com/foo/bar', version: 2),
      );
      final dom = Expert(
        kind: ExpertKind.domain,
        domain: 'ios',
        spec: spec('ios-domain', displayName: 'iOS 领域专家'),
        memory: const ExpertMemory(),
        meta: const ExpertMeta(version: 1),
      );

      await pool.saveProject(proj);
      await pool.saveDomain(dom);

      final summaries = await pool.list();
      expect(summaries.length, 2);

      expect(
        summaries,
        contains(ExpertSummary(
          kind: ExpertKind.project,
          id: 'github.com/foo/bar',
          displayName: '小i',
          version: 2,
        )),
      );
      expect(
        summaries,
        contains(ExpertSummary(
          kind: ExpertKind.domain,
          id: 'ios',
          displayName: 'iOS 领域专家',
          version: 1,
        )),
      );
    });

    test('list skips directories without expert.json', () async {
      // Create a bogus directory under projects/ with no expert.json
      Directory('${root.path}/projects/bogus')
          .createSync(recursive: true);

      await pool.saveProject(Expert(
        kind: ExpertKind.project,
        spec: spec('real'),
        memory: const ExpertMemory(),
        meta: const ExpertMeta(projectId: 'github.com/real/repo'),
      ));

      final summaries = await pool.list();
      expect(summaries.length, 1);
      expect(summaries.first.id, 'github.com/real/repo');
    });
  });

  group('memory protection', () {
    test('pre-existing memory file is not overwritten on re-save', () async {
      final expert = Expert(
        kind: ExpertKind.project,
        spec: spec('ios'),
        memory: const ExpertMemory(
          index: 'expert index',
          solved: [MemoryEntry('handbook.md', 'expert generated content')],
        ),
        meta: const ExpertMeta(projectId: 'github.com/foo/bar'),
      );

      // First save: writes all files fresh.
      await pool.saveProject(expert);

      // User hand-edits the solved file.
      final solvedFile = File(
          '${root.path}/projects/github.com/foo/bar/memory/solved/handbook.md');
      expect(solvedFile.existsSync(), isTrue);
      const userContent = 'user hand-written content — do not overwrite';
      solvedFile.writeAsStringSync(userContent);

      // Re-save the same expert (which would produce different content).
      await pool.saveProject(expert);

      // The user's edit must be preserved.
      expect(solvedFile.readAsStringSync(), userContent);
    });

    test('pre-existing MEMORY.md is not overwritten on re-save', () async {
      final expert = Expert(
        kind: ExpertKind.project,
        spec: spec('ios'),
        memory: const ExpertMemory(index: 'expert index v1'),
        meta: const ExpertMeta(projectId: 'github.com/foo/bar'),
      );

      await pool.saveProject(expert);

      final memFile = File(
          '${root.path}/projects/github.com/foo/bar/memory/MEMORY.md');
      const userContent = 'user edited memory';
      memFile.writeAsStringSync(userContent);

      await pool.saveProject(expert);

      expect(memFile.readAsStringSync(), userContent);
    });
  });

  group('loading non-existent experts', () {
    test('loadProject returns null when not found', () async {
      expect(await pool.loadProject('github.com/no/such'), isNull);
    });

    test('loadDomain returns null when not found', () async {
      expect(await pool.loadDomain('no-such-domain'), isNull);
    });
  });
}
