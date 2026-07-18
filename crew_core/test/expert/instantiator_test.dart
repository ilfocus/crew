// crew_core/test/expert/instantiator_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

AgentCore _core() => const AgentCore(
      id: 'ios-lin',
      name: 'ios-domain',
      displayName: 'iOS 领域专家',
      role: 'iOS 领域工程师',
      personality: '严谨',
      principles: ['不引入未测试依赖'],
      relationships: '',
      tools: ['mcp__foo', 'skill__bar'],
    );

AgentCore _coreNoTools() => const AgentCore(
      id: 'ios-lin',
      name: 'ios-domain',
      displayName: 'iOS 领域专家',
      role: 'iOS 领域工程师',
      personality: '严谨',
      principles: ['不引入未测试依赖'],
    );

DomainExpertise _domain() => const DomainExpertise(
      domain: 'ios',
      notes: 'L2 domain notes',
      principles: ['L2 principle'],
      playbooks: [
        MemoryEntry('排查-内存泄漏.md', '1. Instruments 2. 看堆'),
        MemoryEntry('playbooks/线程.md', '注意主线程'),
      ],
      projects: [
        ProjectRef('github.com/foo/bar', 'iOS APM SDK'),
        ProjectRef('github.com/x/y', 'iOS networking'),
      ],
    );

void main() {
  group('instantiate — spec', () {
    test('brings core personality/principles/role; sets name and repos', () {
      final r = instantiate(
        core: _core(),
        domain: _domain(),
        agentName: 'ios-newproj',
        newRepos: ['~/newproj/ios'],
      );

      expect(r.spec.name, 'ios-newproj');
      expect(r.spec.repos, ['~/newproj/ios']);
      expect(r.spec.personality, '严谨');
      expect(r.spec.principles, ['不引入未测试依赖']);
      expect(r.spec.role, 'iOS 领域工程师');
      expect(r.spec.displayName, 'iOS 领域专家');
    });

    test('does NOT carry L1 specifics: keyFiles/coordinates/techStack/sdks', () {
      final r = instantiate(
        core: _core(),
        domain: _domain(),
        agentName: 'ios-newproj',
        newRepos: ['~/newproj/ios'],
      );

      // L1 specifics not carried over from anywhere
      expect(r.spec.keyFiles, isEmpty);
      expect(r.spec.coordinates, '');
      expect(r.spec.moduleStructure, '');
      expect(r.spec.dataflow, '');
      // techStack/sdks/difficulties are not in DomainExpertise → leave empty
      expect(r.spec.techStack, isEmpty);
      expect(r.spec.sdks, isEmpty);
      expect(r.spec.difficulties, isEmpty);
    });
  });

  group('instantiate — memorySeed', () {
    test('contains MEMORY.md, domain-notes.md, playbooks, projects.md, TOOLS.md',
        () {
      final r = instantiate(
        core: _core(),
        domain: _domain(),
        agentName: 'ios-newproj',
        newRepos: ['~/newproj/ios'],
      );

      final paths = r.memorySeed.map((f) => f.relativePath).toList();

      expect(paths, contains('memory/ios-newproj/MEMORY.md'));
      expect(paths, contains('memory/ios-newproj/domain-notes.md'));
      expect(paths, contains('memory/ios-newproj/playbooks/排查-内存泄漏.md'));
      expect(paths, contains('memory/ios-newproj/playbooks/线程.md'));
      expect(paths, contains('memory/ios-newproj/projects.md'));
      expect(paths, contains('memory/ios-newproj/TOOLS.md'));
    });

    test('TOOLS.md omitted when core.tools is empty', () {
      final r = instantiate(
        core: _coreNoTools(),
        domain: _domain(),
        agentName: 'ios-newproj',
        newRepos: [],
      );

      final paths = r.memorySeed.map((f) => f.relativePath).toList();
      expect(paths.any((p) => p.endsWith('TOOLS.md')), isFalse);
    });

    test('MEMORY.md default mentions agent name and domain', () {
      final r = instantiate(
        core: _core(),
        domain: _domain(),
        agentName: 'ios-newproj',
        newRepos: [],
      );
      final mem = r.memorySeed.firstWhere(
        (f) => f.relativePath == 'memory/ios-newproj/MEMORY.md',
      );
      expect(mem.content, contains('ios-newproj'));
      expect(mem.content, contains('ios'));
    });

    test('domain-notes.md has the L2 notes content', () {
      final r = instantiate(
        core: _core(),
        domain: _domain(),
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
        core: _core(),
        domain: _domain(),
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
        core: _core(),
        domain: _domain(),
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
        core: _core(),
        domain: _domain(),
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
      final r = instantiate(
        core: _core(),
        domain: _domain(),
        agentName: 'ios-newproj',
        newRepos: [],
      );
      final paths = r.memorySeed.map((f) => f.relativePath).toList();
      expect(paths, contains('memory/ios-newproj/playbooks/线程.md'));
      expect(paths.any((p) => p.contains('playbooks/playbooks/')), isFalse,
          reason: 'should not double-nest playbooks/ prefix');
    });

    test('TOOLS.md lists core.tools entries', () {
      final r = instantiate(
        core: _core(),
        domain: _domain(),
        agentName: 'ios-newproj',
        newRepos: [],
      );
      final tools = r.memorySeed.firstWhere(
        (f) => f.relativePath == 'memory/ios-newproj/TOOLS.md',
      );
      expect(tools.content, contains('mcp__foo'));
      expect(tools.content, contains('skill__bar'));
    });
  });
}
