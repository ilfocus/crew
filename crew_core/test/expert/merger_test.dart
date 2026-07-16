// crew_core/test/expert/merger_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

AgentSpec _domainSpec() => const AgentSpec(
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
      techStack: ['Swift'],
    );

AgentSpec _projectSpec() => const AgentSpec(
      name: 'ios',
      displayName: '小i',
      repos: ['~/bm_app/ios'],
      role: 'iOS 开发工程师',
      coordinates: '路径 ~/bm_app/ios',
      moduleStructure: 'Core/',
      keyFiles: [KeyFile('Core/Foo.swift', '上报总线')],
      dataflow: '',
      memoryConvention: '',
      conventions: [],
      techStack: ['Swift', 'SwiftUI'],
      difficulties: ['线程安全'],
    );

Expert _emptyDomain() => Expert(
      kind: ExpertKind.domain,
      domain: 'ios',
      spec: _domainSpec(),
      memory: const ExpertMemory(),
      meta: const ExpertMeta(),
    );

Expert _project({required String projectId, String role = 'iOS APM SDK'}) =>
    Expert(
      kind: ExpertKind.project,
      spec: _projectSpec().copyWith(role: role),
      memory: const ExpertMemory(
        notes: 'L1 notes',
        solved: [MemoryEntry('solved/x.md', 'fix X')],
        playbooks: [MemoryEntry('playbooks/old.md', 'old playbook')],
      ),
      meta: ExpertMeta(projectId: projectId, version: 1),
    );

void main() {
  group('mergeIntoDomain — empty domain + one project', () {
    test('domain has distill output, projects has 1, learnedProjectIds has 1',
        () async {
      final project = _project(projectId: 'github.com/foo/bar');
      final runner = FakeRunner(
        (dir, t) => '{}',
        distillResponder: (prompt) =>
            '{"domainNotes":"iOS 通用抽象","playbooks":'
            '[{"path":"排查-内存.md","content":"Instruments"}]}',
      );

      final result = await mergeIntoDomain(
        domain: _emptyDomain(),
        project: project,
        runner: runner,
        version: 5,
      );

      // distill output merged
      expect(result.memory.notes, contains('iOS 通用抽象'));
      expect(result.memory.playbooks.length, 1);
      expect(result.memory.playbooks.first.path, '排查-内存.md');

      // projects ref added
      expect(result.memory.projects.length, 1);
      expect(result.memory.projects.first.id, 'github.com/foo/bar');
      expect(result.memory.projects.first.summary, 'iOS APM SDK');

      // learnedProjectIds updated
      expect(result.meta.learnedProjectIds, ['github.com/foo/bar']);

      // version bumped
      expect(result.meta.version, 5);

      // domain identity preserved
      expect(result.kind, ExpertKind.domain);
      expect(result.domain, 'ios');
      expect(result.spec.name, 'ios-domain');

      // existing domain spec preserved
      expect(result.spec.personality, '严谨');
      expect(result.spec.techStack, ['Swift']);
    });
  });

  group('mergeIntoDomain — idempotency', () {
    test('same project merged twice does not grow projects/learnedProjectIds',
        () async {
      final project = _project(projectId: 'github.com/foo/bar');
      // stable distill output
      final runner = FakeRunner(
        (dir, t) => '{}',
        distillResponder: (prompt) =>
            '{"domainNotes":"相同抽象","playbooks":'
            '[{"path":"排查-内存.md","content":"Instruments"}]}',
      );

      final d1 = await mergeIntoDomain(
        domain: _emptyDomain(),
        project: project,
        runner: runner,
        version: 1,
      );
      final d2 = await mergeIntoDomain(
        domain: d1,
        project: project,
        runner: runner,
        version: 2,
      );

      // projects still only one
      expect(d2.memory.projects.length, 1);
      expect(d2.memory.projects.first.id, 'github.com/foo/bar');

      // learnedProjectIds still only one
      expect(d2.meta.learnedProjectIds.length, 1);
      expect(d2.meta.learnedProjectIds, ['github.com/foo/bar']);

      // playbook deduped by path
      expect(d2.memory.playbooks.length, 1);
      expect(d2.memory.playbooks.first.path, '排查-内存.md');

      // notes still contain the abstraction (may be appended twice but still there)
      expect(d2.memory.notes, contains('相同抽象'));
    });
  });

  group('mergeIntoDomain — multiple different projects', () {
    test('projects grows to 2 and playbooks deduped by path', () async {
      final projectA = _project(projectId: 'github.com/foo/bar', role: 'APM');
      final projectB = _project(projectId: 'github.com/x/y', role: '网络库');

      // Both distills emit a playbook with the same path → should be deduped
      final runner = FakeRunner(
        (dir, t) => '{}',
        distillResponder: (prompt) =>
            '{"domainNotes":"抽象","playbooks":'
            '[{"path":"排查-通用.md","content":"通用步骤"}]}',
      );

      final d1 = await mergeIntoDomain(
        domain: _emptyDomain(),
        project: projectA,
        runner: runner,
        version: 1,
      );
      final d2 = await mergeIntoDomain(
        domain: d1,
        project: projectB,
        runner: runner,
        version: 2,
      );

      // projects grew to 2
      expect(d2.memory.projects.length, 2);
      expect(d2.memory.projects[0].id, 'github.com/foo/bar');
      expect(d2.memory.projects[1].id, 'github.com/x/y');
      expect(d2.memory.projects[1].summary, '网络库');

      // learnedProjectIds has 2
      expect(d2.meta.learnedProjectIds.length, 2);
      expect(d2.meta.learnedProjectIds,
          containsAll(['github.com/foo/bar', 'github.com/x/y']));

      // playbooks deduped by path → only 1
      expect(d2.memory.playbooks.length, 1);
      expect(d2.memory.playbooks.first.path, '排查-通用.md');
    });
  });
}
