// crew_cli/test/use_expert_test.dart
import 'dart:io';

import 'package:crew_cli/src/commands/use_expert.dart';
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

AgentCore _iosCore() => const AgentCore(
      id: 'ios-lin',
      name: 'ios',
      displayName: '小i',
      role: 'iOS 领域工程师',
      personality: '严谨',
      principles: ['不引入未测试依赖'],
      tools: ['SensorsSDK'],
    );

DomainExpertise _iosDomain() => DomainExpertise(
      domain: 'ios',
      notes: 'L2 domain notes',
      playbooks: [
        const MemoryEntry('playbooks/排查-内存泄漏.md', '1. Instruments 2. 看堆'),
        const MemoryEntry('playbooks/线程.md', '注意主线程'),
      ],
      projects: [
        const ProjectRef('github.com/foo/bar', 'iOS APM SDK'),
      ],
    );

void main() {
  late Directory poolDir;
  late Directory intoDir;
  late AgentPool pool;

  setUp(() {
    poolDir = Directory.systemTemp.createTempSync('use_pool');
    intoDir = Directory.systemTemp.createTempSync('use_into');
    pool = AgentPool(poolDir);
  });

  tearDown(() {
    poolDir.deleteSync(recursive: true);
    intoDir.deleteSync(recursive: true);
  });

  group('runUseExpert', () {
    test('writes memory seed (MEMORY.md, domain-notes, playbooks, projects.md) '
        'and spec json; no solved/ entries', () async {
      await pool.save(AgentProfile(core: _iosCore()));
      await pool.saveDomain('ios-lin', _iosDomain());

      final result = await runUseExpert(
        options: UseExpertOptions(
          agentId: 'ios-lin',
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
      expect(
          File('${intoDir.path}/memory/ios-newproj/MEMORY.md').existsSync(),
          isTrue);
      expect(
          result.writtenPaths, contains('memory/ios-newproj/MEMORY.md'));

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

      // No solved/ entries carried over (instantiator doesn't emit them).
      final solvedDir = Directory('${intoDir.path}/memory/ios-newproj/solved');
      expect(solvedDir.existsSync(), isFalse);
      for (final p in result.writtenPaths) {
        expect(p.contains('solved/'), isFalse,
            reason: 'solved/ should not be carried over: $p');
      }
    });

    test('domain-notes.md content matches L2 notes; projects.md lists projects',
        () async {
      await pool.save(AgentProfile(core: _iosCore()));
      await pool.saveDomain('ios-lin', _iosDomain());

      await runUseExpert(
        options: UseExpertOptions(
          agentId: 'ios-lin',
          domain: 'ios',
          intoPath: intoDir.path,
          agentName: 'ios-newproj',
          repos: ['~/newproj/ios', '~/other/ios'],
          poolDir: poolDir,
        ),
      );

      final notes =
          File('${intoDir.path}/memory/ios-newproj/domain-notes.md')
              .readAsStringSync();
      expect(notes, 'L2 domain notes');

      final projects =
          File('${intoDir.path}/memory/ios-newproj/projects.md')
              .readAsStringSync();
      expect(projects, contains('github.com/foo/bar'));
      expect(projects, contains('iOS APM SDK'));
    });

    test('TOOLS.md is written when core.tools is non-empty', () async {
      await pool.save(AgentProfile(core: _iosCore()));
      await pool.saveDomain('ios-lin', _iosDomain());

      await runUseExpert(
        options: UseExpertOptions(
          agentId: 'ios-lin',
          domain: 'ios',
          intoPath: intoDir.path,
          agentName: 'ios-newproj',
          repos: [],
          poolDir: poolDir,
        ),
      );

      expect(
          File('${intoDir.path}/memory/ios-newproj/TOOLS.md').existsSync(),
          isTrue);
    });

    test('preserves existing memory files (isMemory protection)', () async {
      await pool.save(AgentProfile(core: _iosCore()));
      await pool.saveDomain('ios-lin', _iosDomain());

      // Pre-create a MEMORY.md with user content.
      final memFile = File('${intoDir.path}/memory/ios-newproj/MEMORY.md');
      memFile.parent.createSync(recursive: true);
      const userContent = 'user hand-written memory';
      memFile.writeAsStringSync(userContent);

      await runUseExpert(
        options: UseExpertOptions(
          agentId: 'ios-lin',
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

    test('throws ArgumentError when agent not found', () async {
      expect(
        () => runUseExpert(
          options: UseExpertOptions(
            agentId: 'no-such-agent',
            domain: 'ios',
            intoPath: intoDir.path,
            agentName: 'agent',
            repos: [],
            poolDir: poolDir,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when domain not found for agent', () async {
      await pool.save(AgentProfile(core: _iosCore()));

      expect(
        () => runUseExpert(
          options: UseExpertOptions(
            agentId: 'ios-lin',
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
