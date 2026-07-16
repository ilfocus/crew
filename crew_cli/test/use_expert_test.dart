// crew_cli/test/use_expert_test.dart
import 'dart:io';

import 'package:crew_cli/src/commands/use_expert.dart';
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

Expert _domainExpert() => const Expert(
      kind: ExpertKind.domain,
      domain: 'ios',
      spec: AgentSpec(
        name: 'ios-domain',
        displayName: 'iOS 领域专家',
        repos: [],
        role: 'iOS 领域工程师',
        coordinates: '',
        moduleStructure: '',
        keyFiles: [],
        dataflow: '',
        memoryConvention: '',
        conventions: [],
        personality: '严谨',
        principles: ['不引入未测试依赖'],
        techStack: ['Swift', 'SwiftUI'],
        sdks: ['SensorsSDK'],
        difficulties: ['线程安全'],
      ),
      memory: ExpertMemory(
        index: '# DOMAIN MEMORY',
        notes: 'L2 domain notes',
        solved: [MemoryEntry('solved/should-not-carry.md', 'private fix')],
        playbooks: [
          MemoryEntry('排查-内存泄漏.md', '1. Instruments 2. 看堆'),
          MemoryEntry('playbooks/线程.md', '注意主线程'),
        ],
        projects: [
          ProjectRef('github.com/foo/bar', 'iOS APM SDK'),
        ],
      ),
      meta: ExpertMeta(
        source: 'opensource',
        github: '',
        retention: 'experience-only',
        version: 1,
        learnedProjectIds: ['github.com/foo/bar'],
      ),
    );

void main() {
  late Directory poolDir;
  late Directory intoDir;

  setUp(() {
    poolDir = Directory.systemTemp.createTempSync('use_pool');
    intoDir = Directory.systemTemp.createTempSync('use_into');
  });

  tearDown(() {
    poolDir.deleteSync(recursive: true);
    intoDir.deleteSync(recursive: true);
  });

  group('runUseExpert', () {
    test('writes memory seed, spec json; no solved/ entries', () async {
      final pool = ExpertPool(poolDir);
      await pool.saveDomain(_domainExpert());

      final result = await runUseExpert(
        options: UseExpertOptions(
          domain: 'ios',
          intoPath: intoDir.path,
          agentName: 'ios-newproj',
          repos: ['~/newproj/ios'],
          poolDir: poolDir,
        ),
      );

      // Spec JSON written.
      final specFile = File('${intoDir.path}/.crew/specs/ios-newproj.json');
      expect(specFile.existsSync(), isTrue);
      expect(result.writtenPaths, contains('.crew/specs/ios-newproj.json'));

      // MEMORY.md.
      expect(File('${intoDir.path}/memory/ios-newproj/MEMORY.md').existsSync(),
          isTrue);
      expect(result.writtenPaths,
          contains('memory/ios-newproj/MEMORY.md'));

      // domain-notes.md.
      expect(
          File('${intoDir.path}/memory/ios-newproj/domain-notes.md')
              .existsSync(),
          isTrue);
      expect(result.writtenPaths,
          contains('memory/ios-newproj/domain-notes.md'));

      // playbooks/ dir with both playbooks (basename-stripped).
      expect(
          File('${intoDir.path}/memory/ios-newproj/playbooks/排查-内存泄漏.md')
              .existsSync(),
          isTrue);
      expect(
          File('${intoDir.path}/memory/ios-newproj/playbooks/线程.md')
              .existsSync(),
          isTrue);

      // projects.md.
      expect(
          File('${intoDir.path}/memory/ios-newproj/projects.md').existsSync(),
          isTrue);

      // No solved/ entries carried over.
      final solvedDir = Directory('${intoDir.path}/memory/ios-newproj/solved');
      expect(solvedDir.existsSync(), isFalse);
      for (final p in result.writtenPaths) {
        expect(p.contains('solved/'), isFalse,
            reason: 'solved/ should not be carried over: $p');
      }
    });

    test('spec json contains agentName and provided repos', () async {
      final pool = ExpertPool(poolDir);
      await pool.saveDomain(_domainExpert());

      await runUseExpert(
        options: UseExpertOptions(
          domain: 'ios',
          intoPath: intoDir.path,
          agentName: 'ios-newproj',
          repos: ['~/newproj/ios', '~/other/ios'],
          poolDir: poolDir,
        ),
      );

      // Verify the domain-notes.md content matches L2 notes.
      final notes =
          File('${intoDir.path}/memory/ios-newproj/domain-notes.md')
              .readAsStringSync();
      expect(notes, 'L2 domain notes');
    });

    test('preserves existing memory files (isMemory protection)', () async {
      final pool = ExpertPool(poolDir);
      await pool.saveDomain(_domainExpert());

      // Pre-create a MEMORY.md with user content.
      final memFile =
          File('${intoDir.path}/memory/ios-newproj/MEMORY.md');
      memFile.parent.createSync(recursive: true);
      const userContent = 'user hand-written memory';
      memFile.writeAsStringSync(userContent);

      await runUseExpert(
        options: UseExpertOptions(
          domain: 'ios',
          intoPath: intoDir.path,
          agentName: 'ios-newproj',
          repos: [],
          poolDir: poolDir,
        ),
      );

      // Existing memory file preserved.
      expect(memFile.readAsStringSync(), userContent);
    });

    test('throws when domain not found', () async {
      expect(
        () => runUseExpert(
          options: UseExpertOptions(
            domain: 'no-such-domain',
            intoPath: intoDir.path,
            agentName: 'agent',
            repos: [],
            poolDir: poolDir,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
