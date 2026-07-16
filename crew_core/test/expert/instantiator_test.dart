// crew_core/test/expert/instantiator_test.dart
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
          ProjectRef('github.com/x/y', 'iOS networking'),
        ],
      ),
      meta: ExpertMeta(
        source: 'opensource',
        github: '',
        retention: 'experience-only',
        version: 1,
        learnedProjectIds: ['github.com/foo/bar', 'github.com/x/y'],
      ),
    );

void main() {
  group('instantiate — spec', () {
    test('brings domain personality/principles/techStack; sets name and repos',
        () {
      final r = instantiate(
        domain: _domainExpert(),
        agentName: 'ios-newproj',
        newRepos: ['~/newproj/ios'],
      );

      expect(r.spec.name, 'ios-newproj');
      expect(r.spec.repos, ['~/newproj/ios']);

      // transferable fields preserved from domain
      expect(r.spec.personality, '严谨');
      expect(r.spec.principles, ['不引入未测试依赖']);
      expect(r.spec.techStack, ['Swift', 'SwiftUI']);
      expect(r.spec.sdks, ['SensorsSDK']);
      expect(r.spec.difficulties, ['线程安全']);
      expect(r.spec.role, 'iOS 领域工程师');
    });
  });

  group('instantiate — memorySeed', () {
    test('contains MEMORY.md, domain-notes.md, playbooks, projects.md', () {
      final r = instantiate(
        domain: _domainExpert(),
        agentName: 'ios-newproj',
        newRepos: ['~/newproj/ios'],
      );

      final paths = r.memorySeed.map((f) => f.relativePath).toList();

      expect(paths, contains('memory/ios-newproj/MEMORY.md'));
      expect(paths, contains('memory/ios-newproj/domain-notes.md'));
      expect(paths, contains('memory/ios-newproj/playbooks/排查-内存泄漏.md'));
      expect(paths, contains('memory/ios-newproj/playbooks/线程.md'));
      expect(paths, contains('memory/ios-newproj/projects.md'));
    });

    test('MEMORY.md uses domain.memory.index when provided', () {
      final r = instantiate(
        domain: _domainExpert(),
        agentName: 'ios-newproj',
        newRepos: [],
      );
      final mem = r.memorySeed.firstWhere(
        (f) => f.relativePath == 'memory/ios-newproj/MEMORY.md',
      );
      expect(mem.content, '# DOMAIN MEMORY');
    });

    test('MEMORY.md falls back to default when index empty', () {
      final domain = _domainExpert();
      // build a copy with empty index using toJson/fromJson round-trip
      final modified = Expert.fromJson(domain.toJson()).copyWithMemoryIndex('');
      final r = instantiate(
        domain: modified,
        agentName: 'agentX',
        newRepos: [],
      );
      final mem = r.memorySeed.firstWhere(
        (f) => f.relativePath == 'memory/agentX/MEMORY.md',
      );
      expect(mem.content, contains('# MEMORY — agentX'));
    });

    test('domain-notes.md has the L2 notes content', () {
      final r = instantiate(
        domain: _domainExpert(),
        agentName: 'ios-newproj',
        newRepos: [],
      );
      final notes = r.memorySeed.firstWhere(
        (f) => f.relativePath == 'memory/ios-newproj/domain-notes.md',
      );
      expect(notes.content, 'L2 domain notes');
    });

    test('projects.md contains all project refs', () {
      final r = instantiate(
        domain: _domainExpert(),
        agentName: 'ios-newproj',
        newRepos: [],
      );
      final projects = r.memorySeed.firstWhere(
        (f) => f.relativePath == 'memory/ios-newproj/projects.md',
      );
      expect(projects.content, contains('github.com/foo/bar'));
      expect(projects.content, contains('iOS APM SDK'));
      expect(projects.content, contains('github.com/x/y'));
      expect(projects.content, contains('iOS networking'));
    });

    test('does NOT contain any solved/ entries', () {
      final r = instantiate(
        domain: _domainExpert(),
        agentName: 'ios-newproj',
        newRepos: [],
      );
      for (final f in r.memorySeed) {
        expect(f.relativePath.contains('solved/'), isFalse,
            reason: 'solved/ entries should not be carried over: '
                '${f.relativePath}');
      }
    });

    test('all memorySeed items have isMemory=true', () {
      final r = instantiate(
        domain: _domainExpert(),
        agentName: 'ios-newproj',
        newRepos: [],
      );
      expect(r.memorySeed, isNotEmpty);
      for (final f in r.memorySeed) {
        expect(f.isMemory, isTrue,
            reason: 'expected isMemory=true for ${f.relativePath}');
      }
    });

    test('playbook path prefix is stripped into playbooks/ dir', () {
      // domain has playbook with path 'playbooks/线程.md' — should be written
      // as 'memory/<agent>/playbooks/线程.md' (not .../playbooks/playbooks/线程.md)
      final r = instantiate(
        domain: _domainExpert(),
        agentName: 'ios-newproj',
        newRepos: [],
      );
      final paths = r.memorySeed.map((f) => f.relativePath).toList();
      expect(paths, contains('memory/ios-newproj/playbooks/线程.md'));
      expect(paths.any((p) => p.contains('playbooks/playbooks/')), isFalse,
          reason: 'should not double-nest playbooks/ prefix');
    });
  });
}

/// Helper extension to make a copy of Expert with modified memory.index.
extension on Expert {
  Expert copyWithMemoryIndex(String newIndex) {
    return Expert(
      kind: kind,
      domain: domain,
      spec: spec,
      memory: ExpertMemory(
        index: newIndex,
        notes: memory.notes,
        solved: memory.solved,
        playbooks: memory.playbooks,
        projects: memory.projects,
      ),
      meta: meta,
    );
  }
}
