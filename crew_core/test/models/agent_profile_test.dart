// crew_core/test/models/agent_profile_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  group('AgentProfile', () {
    test('agent.json (core+memory+meta) round-trip', () {
      const core = AgentCore(
        id: 'ios-lin',
        name: 'ios',
        displayName: '小林',
        role: 'iOS 开发工程师',
        personality: '严谨',
        principles: ['不引入未测试依赖'],
        relationships: '# 用户\n偏好简洁',
        tools: ['firecrawl'],
      );
      const memory = AgentMemory(
        index: '# MEMORY',
        shortTerm: '近期: 任务X',
        longTerm: [MemoryEntry('recap.md', '# 总览')],
      );
      const meta = AgentMeta(version: 3);
      const profile = AgentProfile(
        core: core,
        memory: memory,
        meta: meta,
      );

      final j = profile.toJson();
      // domains/projects 不进 agent.json
      expect(j.keys.toSet(), {'core', 'memory', 'meta'});
      expect((j['core'] as Map)['id'], 'ios-lin');
      expect((j['memory'] as Map)['shortTerm'], '近期: 任务X');
      expect((j['meta'] as Map)['version'], 3);

      final r = AgentProfile.fromJson(j);
      expect(r.core.id, 'ios-lin');
      expect(r.core.personality, '严谨');
      expect(r.memory.shortTerm, '近期: 任务X');
      expect(r.memory.longTerm.length, 1);
      expect(r.meta.version, 3);
      // 默认 domains/projects 为空
      expect(r.domains, isEmpty);
      expect(r.projects, isEmpty);
    });

    test('withProject replaces same projectId (idempotent dedup)', () {
      const core = AgentCore(id: 'a', name: 'a', displayName: 'A', role: 'r');
      const p1 = ProjectCompetence(
        projectId: 'p1',
        notes: 'first',
        domains: ['ios'],
      );
      const p2 = ProjectCompetence(
        projectId: 'p1', // 同 id
        notes: 'second (overwrite)',
        domains: ['ios', 'apm'],
      );
      const p3 = ProjectCompetence(projectId: 'p3', notes: 'third');
      var profile = const AgentProfile(core: core);
      profile = profile.withProject(p1);
      expect(profile.projects.length, 1);
      expect(profile.projects.single.notes, 'first');

      // 同 id 覆盖
      profile = profile.withProject(p2);
      expect(profile.projects.length, 1, reason: '同 projectId 应替换而非追加');
      expect(profile.projects.single.notes, 'second (overwrite)');
      expect(profile.projects.single.domains, ['ios', 'apm']);

      // 新 id 追加
      profile = profile.withProject(p3);
      expect(profile.projects.length, 2);
      expect(profile.projects[0].projectId, 'p1');
      expect(profile.projects[1].projectId, 'p3');
    });

    test('withDomain replaces same domain (idempotent dedup)', () {
      const core = AgentCore(id: 'a', name: 'a', displayName: 'A', role: 'r');
      const d1 = DomainExpertise(domain: 'ios', notes: 'first');
      const d2 = DomainExpertise(domain: 'ios', notes: 'second (overwrite)');
      const d3 = DomainExpertise(domain: 'quant', notes: 'third');
      var profile = const AgentProfile(core: core);
      profile = profile.withDomain(d1);
      expect(profile.domains.length, 1);
      expect(profile.domains.single.notes, 'first');

      profile = profile.withDomain(d2);
      expect(profile.domains.length, 1, reason: '同 domain 应替换而非追加');
      expect(profile.domains.single.notes, 'second (overwrite)');

      profile = profile.withDomain(d3);
      expect(profile.domains.length, 2);
      expect(profile.domains[0].domain, 'ios');
      expect(profile.domains[1].domain, 'quant');
    });

    test('fromJson tolerates missing domains/projects (agent.json only)',
        () {
      final j = {
        'core': {'id': 'x', 'name': 'n', 'displayName': 'X', 'role': 'r'},
        'memory': {},
        'meta': {},
      };
      final r = AgentProfile.fromJson(j);
      expect(r.core.id, 'x');
      expect(r.domains, isEmpty);
      expect(r.projects, isEmpty);
    });

    test('withProject/withDomain chain builds complete profile', () {
      const core = AgentCore(id: 'a', name: 'a', displayName: 'A', role: 'r');
      const d1 = DomainExpertise(domain: 'ios');
      const d2 = DomainExpertise(domain: 'quant');
      const p1 = ProjectCompetence(projectId: 'p1');
      const p2 = ProjectCompetence(projectId: 'p2');
      const p3 = ProjectCompetence(projectId: 'p3');

      final profile = const AgentProfile(core: core)
          .withDomain(d1)
          .withDomain(d2)
          .withProject(p1)
          .withProject(p2)
          .withProject(p3);

      expect(profile.domains.length, 2);
      expect(profile.projects.length, 3);
    });
  });
}
