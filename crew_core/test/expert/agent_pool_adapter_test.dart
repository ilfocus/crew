// crew_core/test/expert/agent_pool_adapter_test.dart
import 'dart:convert';

import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  /// 构造填满的 AgentProfile：1 domain + 2 projects。
  /// project 'p1' 被两个 domain 都引用（多对多）。
  AgentProfile _buildFullProfile() {
    const core = AgentCore(
      id: 'ios-lin',
      name: 'ios',
      displayName: '小林',
      role: 'iOS 开发工程师',
      personality: '严谨',
      principles: ['不引入未测试依赖', '线程安全优先'],
      relationships: '# 用户画像\n偏好简洁回答\n\n## 协作\n- pm: 接收需求',
      tools: ['firecrawl', 'gh-cli'],
    );
    const memory = AgentMemory(
      index: '# MEMORY index',
      shortTerm: '近期: 任务 X 进行中',
      longTerm: [
        MemoryEntry('recap.md', '# 7 月总结'),
        MemoryEntry('patterns/swift.md', 'actor 心得'),
      ],
    );
    const meta = AgentMeta(version: 2);
    const d1 = DomainExpertise(
      domain: 'ios',
      notes: 'iOS L2 经验',
      principles: ['避免 retain cycle'],
      playbooks: [MemoryEntry('playbooks/swift-actor.md', 'actor 心得')],
      projects: [
        ProjectRef('p1', 'iOS 视角'),
        ProjectRef('p2', 'iOS 视角'),
      ],
    );
    const d2 = DomainExpertise(
      domain: 'apm',
      notes: 'APM L2',
      projects: [ProjectRef('p1', 'APM 视角')], // p1 多对多
    );
    const p1 = ProjectCompetence(
      projectId: 'p1',
      repos: ['~/r'],
      coordinates: 'Core/BMApm',
      moduleStructure: 'Core/ 单例',
      keyFiles: [KeyFile('Core/BMApm.swift:279', '上报总线')],
      dataflow: '采集 → 神策',
      techStack: ['Swift'],
      sdks: ['SensorsSDK'],
      difficulties: ['线程安全'],
      github: 'https://github.com/foo/bar',
      source: 'opensource',
      retention: 'full',
      notes: 'L1 p1 笔记',
      solved: [MemoryEntry('solved/leak.md', '修了泄漏')],
      playbooks: [MemoryEntry('playbooks/apm.md', 'APM 套路')],
      domains: ['ios', 'apm'],
    );
    const p2 = ProjectCompetence(
      projectId: 'p2',
      repos: [],
      notes: 'L1 p2 笔记',
      domains: ['ios'],
    );
    return const AgentProfile(
      core: core,
      memory: memory,
      meta: meta,
      domains: [d1, d2],
      projects: [p1, p2],
    );
  }

  group('AgentPoolAdapter.render', () {
    final adapter = const AgentPoolAdapter();

    test('produces all expected agent-level files', () {
      final arts = adapter.render(_buildFullProfile());
      final paths = arts.map((a) => a.relativePath).toSet();

      // agent.json + IDENTITY / RELATIONSHIPS / TOOLS.md
      expect(paths, contains('agent.json'));
      expect(paths, contains('IDENTITY.md'));
      expect(paths, contains('RELATIONSHIPS.md'));
      expect(paths, contains('TOOLS.md'));
      // memory
      expect(paths, contains('memory/MEMORY.md'));
      expect(paths, contains('memory/short-term.md'));
      expect(paths, contains('memory/long-term/recap.md'));
      expect(paths, contains('memory/long-term/patterns/swift.md'));
    });

    test('produces domain files for each domain', () {
      final arts = adapter.render(_buildFullProfile());
      final paths = arts.map((a) => a.relativePath).toSet();

      // domain ios
      expect(paths, contains('domains/ios/domain.json'));
      expect(paths, contains('domains/ios/EXPERTISE.md'));
      // playbooks/swift-actor.md → swift-actor.md（_stripPrefix）
      expect(paths, contains('domains/ios/playbooks/swift-actor.md'));
      expect(paths, contains('domains/ios/projects.md'));
      // domain apm
      expect(paths, contains('domains/apm/domain.json'));
      expect(paths, contains('domains/apm/EXPERTISE.md'));
      expect(paths, contains('domains/apm/projects.md'));
    });

    test('produces project files for each project (nested project-id ok)', () {
      final profile = _buildFullProfile().withProject(
        const ProjectCompetence(
          projectId: 'github.com/foo/bar',
          notes: 'nested',
        ),
      );
      final arts = adapter.render(profile);
      final paths = arts.map((a) => a.relativePath).toSet();

      // 简单 project-id
      expect(paths, contains('projects/p1/project.json'));
      expect(paths, contains('projects/p1/COMPETENCE.md'));
      expect(paths, contains('projects/p1/memory/project-notes.md'));
      // _stripPrefix：solved/leak.md → leak.md
      expect(paths, contains('projects/p1/memory/solved/leak.md'));
      // playbooks/apm.md → apm.md
      expect(paths, contains('projects/p1/memory/playbooks/apm.md'));

      // 嵌套 project-id（含 /）→ 嵌套目录
      expect(paths, contains('projects/github.com/foo/bar/project.json'));
      expect(paths, contains('projects/github.com/foo/bar/COMPETENCE.md'));
      expect(paths, contains('projects/github.com/foo/bar/memory/project-notes.md'));
    });

    test('agent.json / domain.json / project.json round-trip back', () {
      final profile = _buildFullProfile();
      final arts = adapter.render(profile);
      final byPath = {for (final a in arts) a.relativePath: a};

      // agent.json
      final agentJson =
          jsonDecodeAsMap(byPath['agent.json']!.content);
      final restoredAgent = AgentProfile.fromJson(agentJson);
      expect(restoredAgent.core.id, 'ios-lin');
      expect(restoredAgent.core.personality, '严谨');
      expect(restoredAgent.memory.shortTerm, '近期: 任务 X 进行中');
      expect(restoredAgent.memory.longTerm.length, 2);

      // domain.json (ios)
      final dJson = jsonDecodeAsMap(byPath['domains/ios/domain.json']!.content);
      final rd = DomainExpertise.fromJson(dJson);
      expect(rd.domain, 'ios');
      expect(rd.notes, 'iOS L2 经验');
      expect(rd.playbooks.length, 1);
      expect(rd.projects.length, 2);

      // project.json (p1)
      final pJson =
          jsonDecodeAsMap(byPath['projects/p1/project.json']!.content);
      final rp = ProjectCompetence.fromJson(pJson);
      expect(rp.projectId, 'p1');
      expect(rp.keyFiles.length, 1);
      expect(rp.keyFiles.first.path, 'Core/BMApm.swift:279');
      expect(rp.domains, ['ios', 'apm']);
    });

    test('memory files are isMemory=true; views/JSON are isMemory=false', () {
      final arts = adapter.render(_buildFullProfile());
      final byPath = {for (final a in arts) a.relativePath: a};

      // 视图 + JSON → false
      expect(byPath['agent.json']!.isMemory, isFalse);
      expect(byPath['IDENTITY.md']!.isMemory, isFalse);
      expect(byPath['RELATIONSHIPS.md']!.isMemory, isFalse);
      expect(byPath['TOOLS.md']!.isMemory, isFalse);
      expect(byPath['domains/ios/domain.json']!.isMemory, isFalse);
      expect(byPath['domains/ios/EXPERTISE.md']!.isMemory, isFalse);
      expect(byPath['projects/p1/project.json']!.isMemory, isFalse);
      expect(byPath['projects/p1/COMPETENCE.md']!.isMemory, isFalse);

      // 记忆 → true
      expect(byPath['memory/MEMORY.md']!.isMemory, isTrue);
      expect(byPath['memory/short-term.md']!.isMemory, isTrue);
      expect(byPath['memory/long-term/recap.md']!.isMemory, isTrue);
      expect(byPath['domains/ios/playbooks/swift-actor.md']!.isMemory,
          isTrue);
      expect(byPath['domains/ios/projects.md']!.isMemory, isTrue);
      expect(byPath['projects/p1/memory/project-notes.md']!.isMemory, isTrue);
      expect(byPath['projects/p1/memory/solved/leak.md']!.isMemory,
          isTrue);
      expect(byPath['projects/p1/memory/playbooks/apm.md']!.isMemory,
          isTrue);
    });

    test('multi-many: project p1 appears in both domains projects.md', () {
      final arts = adapter.render(_buildFullProfile());
      final byPath = {for (final a in arts) a.relativePath: a};

      final iosProjects = byPath['domains/ios/projects.md']!.content;
      final apmProjects = byPath['domains/apm/projects.md']!.content;
      expect(iosProjects, contains('p1'));
      expect(apmProjects, contains('p1'));
      // p2 仅在 ios
      expect(iosProjects, contains('p2'));
      expect(apmProjects.contains('p2'), isFalse);
    });

    test(
        'empty long-term / solved / playbooks produce placeholder README.md '
        'instead of missing directories', () {
      const core = AgentCore(
          id: 'empty', name: 'e', displayName: 'E', role: 'r');
      const d = DomainExpertise(domain: 'd1'); // 空 playbooks
      const p = ProjectCompetence(projectId: 'p1'); // 空 solved+playbooks
      const profile =
          AgentProfile(core: core, domains: [d], projects: [p]);

      final arts = adapter.render(profile);
      final paths = arts.map((a) => a.relativePath).toSet();
      // agent long-term README
      expect(paths, contains('memory/long-term/README.md'));
      // domain playbooks README
      expect(paths, contains('domains/d1/playbooks/README.md'));
      // project solved + playbooks README
      expect(paths, contains('projects/p1/memory/solved/README.md'));
      expect(paths, contains('projects/p1/memory/playbooks/README.md'));
    });

    test('IDENTITY.md includes personality / role / principles', () {
      final arts = adapter.render(_buildFullProfile());
      final id = arts.firstWhere((a) => a.relativePath == 'IDENTITY.md').content;
      expect(id, contains('iOS 开发工程师'));
      expect(id, contains('严谨'));
      expect(id, contains('不引入未测试依赖'));
    });

    test('RELATIONSHIPS.md includes core.relationships verbatim', () {
      final arts = adapter.render(_buildFullProfile());
      final r =
          arts.firstWhere((a) => a.relativePath == 'RELATIONSHIPS.md').content;
      expect(r, contains('用户画像'));
      expect(r, contains('pm: 接收需求'));
    });

    test('TOOLS.md lists core.tools', () {
      final arts = adapter.render(_buildFullProfile());
      final t =
          arts.firstWhere((a) => a.relativePath == 'TOOLS.md').content;
      expect(t, contains('firecrawl'));
      expect(t, contains('gh-cli'));
    });
  });
}

Map<String, dynamic> jsonDecodeAsMap(String s) =>
    Map<String, dynamic>.from(jsonDecode(s) as Map);
