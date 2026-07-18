// crew_core/test/expert/agent_pool_test.dart
import 'dart:io';

import 'package:crew_core/crew_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late AgentPool pool;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('agent_pool_test');
    pool = AgentPool(Directory(p.join(tmp.path, 'pool')));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  AgentProfile _fullProfile() {
    return const AgentProfile(
      core: AgentCore(
        id: 'ios-lin',
        name: 'ios',
        displayName: '小林',
        role: 'iOS 开发工程师',
        personality: '严谨',
        principles: ['不引入未测试依赖'],
        relationships: '# 用户',
        tools: ['firecrawl'],
      ),
      memory: AgentMemory(
        index: '# INDEX',
        shortTerm: '近期: X',
        longTerm: [MemoryEntry('recap.md', '总览')],
      ),
      meta: AgentMeta(version: 2),
      domains: [
        DomainExpertise(
          domain: 'ios',
          notes: 'iOS L2',
          playbooks: [MemoryEntry('playbooks/swift.md', 'swift 心得')],
          projects: [ProjectRef('p1', 'iOS 视角')],
        ),
        DomainExpertise(
          domain: 'apm',
          notes: 'APM L2',
          projects: [ProjectRef('p1', 'APM 视角')],
        ),
      ],
      projects: [
        ProjectCompetence(
          projectId: 'p1',
          repos: ['~/r'],
          coordinates: 'Core/BMApm',
          notes: 'L1 notes p1',
          solved: [MemoryEntry('solved/leak.md', '修了泄漏')],
          playbooks: [MemoryEntry('playbooks/apm.md', 'APM 套路')],
          domains: ['ios', 'apm'],
        ),
        ProjectCompetence(
          projectId: 'p2',
          notes: 'L1 notes p2',
          domains: ['ios'],
        ),
      ],
    );
  }

  group('AgentPool save/load', () {
    test('save(agent) → load(id) round-trips core/memory/domains/projects',
        () async {
      final original = _fullProfile();
      await pool.save(original);

      final loaded = await pool.load('ios-lin');
      expect(loaded, isNotNull);
      expect(loaded!.core.id, 'ios-lin');
      expect(loaded.core.personality, '严谨');
      expect(loaded.core.principles, ['不引入未测试依赖']);
      expect(loaded.core.tools, ['firecrawl']);
      expect(loaded.memory.index, '# INDEX');
      expect(loaded.memory.shortTerm, '近期: X');
      expect(loaded.memory.longTerm.length, 1);
      expect(loaded.memory.longTerm.first.path, 'recap.md');

      // domains
      expect(loaded.domains.length, 2);
      final ios = loaded.domains.firstWhere((d) => d.domain == 'ios');
      expect(ios.notes, 'iOS L2');
      expect(ios.playbooks.length, 1);
      expect(ios.projects.length, 1);
      expect(ios.projects.first.id, 'p1');

      // projects
      expect(loaded.projects.length, 2);
      final p1 = loaded.projects.firstWhere((p) => p.projectId == 'p1');
      expect(p1.coordinates, 'Core/BMApm');
      expect(p1.notes, 'L1 notes p1');
      expect(p1.solved.length, 1);
      expect(p1.solved.first.content, '修了泄漏');
      expect(p1.domains, ['ios', 'apm']);
    });

    test('load returns null when agentId absent', () async {
      expect(await pool.load('nonexistent'), isNull);
    });

    test('save writes to <root>/agents/<id>/', () async {
      await pool.save(_fullProfile());
      final agentJson =
          File('${pool.root.path}/agents/ios-lin/agent.json');
      expect(agentJson.existsSync(), isTrue);
      final dJson =
          File('${pool.root.path}/agents/ios-lin/domains/ios/domain.json');
      expect(dJson.existsSync(), isTrue);
      final pJson =
          File('${pool.root.path}/agents/ios-lin/projects/p1/project.json');
      expect(pJson.existsSync(), isTrue);
    });
  });

  group('AgentPool fine-grained API', () {
    test('saveProject / loadProject individually', () async {
      // 先用 save 写一个 agent 然后单独 saveProject 替换 project
      await pool.save(_fullProfile());
      // 保存一个新的 project（覆盖 p1）
      const newP1 = ProjectCompetence(
        projectId: 'p1',
        notes: 'updated notes',
        coordinates: 'NEW_COORDS',
        domains: ['ios', 'apm'],
      );
      await pool.saveProject('ios-lin', newP1);

      final loaded = await pool.loadProject('ios-lin', 'p1');
      expect(loaded, isNotNull);
      expect(loaded!.notes, 'updated notes');
      expect(loaded.coordinates, 'NEW_COORDS');
    });

    test('saveProject without pre-existing agent writes project files only',
        () async {
      // 在 agent.json 还不存在时，saveProject 仅写 projects/<pid>/**。
      // load(agentId) 仍返回 null（缺 agent.json，主体未建）；
      // 但 loadProject 能读回——验证细粒度 API 不依赖完整 agent 已落盘。
      const proj = ProjectCompetence(projectId: 'p1', notes: 'from scratch');
      await pool.saveProject('fresh-agent', proj);

      expect(await pool.loadProject('fresh-agent', 'p1'), isNotNull);
      // 主体未建：load(agentId) 应返回 null
      expect(await pool.load('fresh-agent'), isNull);
    });

    test('saveDomain / loadDomain individually', () async {
      await pool.save(_fullProfile());
      const newD = DomainExpertise(
        domain: 'ios',
        notes: 'updated ios notes',
        projects: [ProjectRef('p1', 'iOS 视角 v2')],
      );
      await pool.saveDomain('ios-lin', newD);

      final loaded = await pool.loadDomain('ios-lin', 'ios');
      expect(loaded, isNotNull);
      expect(loaded!.notes, 'updated ios notes');
      expect(loaded.projects.first.summary, 'iOS 视角 v2');
    });

    test('loadProject / loadDomain return null when absent', () async {
      await pool.save(_fullProfile());
      expect(await pool.loadProject('ios-lin', 'no-such'), isNull);
      expect(await pool.loadDomain('ios-lin', 'no-such'), isNull);
    });
  });

  group('AgentPool.list', () {
    test('returns AgentSummary per agent', () async {
      final p1 = _fullProfile();
      const p2 = AgentProfile(
        core: AgentCore(id: 'pm-sue', name: 'pm', displayName: '苏', role: 'PM'),
        domains: [],
        projects: [],
      );
      await pool.save(p1);
      await pool.save(p2);

      final summaries = await pool.list();
      expect(summaries.length, 2);
      final ids = summaries.map((s) => s.id).toSet();
      expect(ids, {'ios-lin', 'pm-sue'});

      final iosSum = summaries.firstWhere((s) => s.id == 'ios-lin');
      expect(iosSum.displayName, '小林');
      expect(iosSum.domains, containsAll(['ios', 'apm']));
      expect(iosSum.projectCount, 2);
      expect(iosSum.version, 2);
    });

    test('returns empty list when root does not exist', () async {
      final dead = AgentPool(Directory('${tmp.path}/no-such'));
      expect(await dead.list(), isEmpty);
    });
  });

  group('AgentPool.delete', () {
    test('removes the agent directory recursively', () async {
      await pool.save(_fullProfile());
      await pool.delete('ios-lin');
      expect(await pool.load('ios-lin'), isNull);
      // 目录确实没了
      final agentDir = Directory('${pool.root.path}/agents/ios-lin');
      expect(agentDir.existsSync(), isFalse);
    });

    test('delete is no-op when absent', () async {
      // 不应抛
      await pool.delete('nonexistent');
    });
  });

  group('AgentPool memory protection', () {
    test('save does not overwrite pre-existing memory files', () async {
      // 1. 先 save 一次（profile.solved 含 'leak.md'）
      await pool.save(_fullProfile());
      // 2. 用户手动改写 leak.md 内容
      final userSolved = File(
          '${pool.root.path}/agents/ios-lin/projects/p1/memory/solved/leak.md');
      expect(userSolved.existsSync(), isTrue);
      const userContent = 'user hand-written — do not overwrite';
      userSolved.writeAsStringSync(userContent);

      // 3. 再次 save（profile 不变；按 WritePlanner 规则 isMemory 文件 skip）
      await pool.save(_fullProfile());

      // 4. 用户文件内容被保留
      expect(userSolved.readAsStringSync(), userContent);
    });

    test('save does not overwrite pre-existing long-term entries',
        () async {
      await pool.save(_fullProfile());
      final lt = File(
          '${pool.root.path}/agents/ios-lin/memory/long-term/recap.md');
      expect(lt.existsSync(), isTrue);
      const userContent = 'user-edited long term';
      lt.writeAsStringSync(userContent);

      await pool.save(_fullProfile());

      expect(lt.readAsStringSync(), userContent);
    });

    test('new memory entries (not yet on disk) are still written', () async {
      // 第一次 save：longTerm=[recap.md]
      await pool.save(_fullProfile());
      // 第二次 save：profile 多了一条 long-term
      final updated = AgentProfile(
        core: const AgentCore(
          id: 'ios-lin',
          name: 'ios',
          displayName: '小林',
          role: 'iOS 开发工程师',
          personality: '严谨',
          principles: ['不引入未测试依赖'],
          relationships: '# 用户',
          tools: ['firecrawl'],
        ),
        memory: const AgentMemory(
          index: '# INDEX',
          shortTerm: '近期: X',
          longTerm: [
            MemoryEntry('recap.md', '总览'),
            MemoryEntry('new-entry.md', 'newly added'),
          ],
        ),
        meta: const AgentMeta(version: 2),
      );
      await pool.save(updated);
      // recap.md 已存在 → skip；new-entry.md 应被写入
      final newLt = File(
          '${pool.root.path}/agents/ios-lin/memory/long-term/new-entry.md');
      expect(newLt.existsSync(), isTrue);
      expect(newLt.readAsStringSync(), 'newly added');
    });
  });

  group('AgentPool nested project-id', () {
    test('project-id with slash maps to nested directories', () async {
      const profile = AgentProfile(
        core: AgentCore(id: 'a', name: 'a', displayName: 'A', role: 'r'),
        projects: [
          ProjectCompetence(
            projectId: 'github.com/foo/bar',
            notes: 'nested project',
          ),
        ],
      );
      await pool.save(profile);

      final loaded = await pool.load('a');
      expect(loaded!.projects.length, 1);
      expect(loaded.projects.first.projectId, 'github.com/foo/bar');
      expect(loaded.projects.first.notes, 'nested project');

      // 文件结构
      final pJson = File(
          '${pool.root.path}/agents/a/projects/github.com/foo/bar/project.json');
      expect(pJson.existsSync(), isTrue);
    });
  });
}
