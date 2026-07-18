// crew_core/test/models/agent_core_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  group('AgentCore', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      const core = AgentCore(
        id: 'ios-lin',
        name: 'ios',
        displayName: '小林',
        role: 'iOS 开发工程师',
        personality: '严谨、克制、重视证据',
        principles: ['不引入未测试依赖', '线程安全优先'],
        relationships: '# 用户画像\n偏好简洁回答\n\n## 协作\n- pm: 接收需求',
        tools: ['firecrawl', 'gh-cli', 'mcp:filesystem'],
      );
      final j = core.toJson();
      expect(j['id'], 'ios-lin');
      expect(j['name'], 'ios');
      expect(j['displayName'], '小林');
      expect(j['role'], 'iOS 开发工程师');
      expect(j['personality'], '严谨、克制、重视证据');
      expect(j['principles'], ['不引入未测试依赖', '线程安全优先']);
      expect(j['relationships'], contains('用户画像'));
      expect(j['tools'], ['firecrawl', 'gh-cli', 'mcp:filesystem']);

      final r = AgentCore.fromJson(j);
      expect(r.id, 'ios-lin');
      expect(r.name, 'ios');
      expect(r.displayName, '小林');
      expect(r.role, 'iOS 开发工程师');
      expect(r.personality, '严谨、克制、重视证据');
      expect(r.principles, ['不引入未测试依赖', '线程安全优先']);
      expect(r.relationships, contains('用户画像'));
      expect(r.tools, ['firecrawl', 'gh-cli', 'mcp:filesystem']);
    });

    test('fromJson with empty map yields defaults', () {
      final r = AgentCore.fromJson({});
      expect(r.id, '');
      expect(r.name, '');
      expect(r.displayName, '');
      expect(r.role, '');
      expect(r.personality, '');
      expect(r.principles, isEmpty);
      expect(r.relationships, '');
      expect(r.tools, isEmpty);
    });

    test('fromJson tolerates malformed list field (coerces to string list)',
        () {
      final r = AgentCore.fromJson({
        'id': 'x',
        'name': 'n',
        'principles': ['a', 1, true], // 混合类型
        'tools': [42, 'b'],
      });
      expect(r.id, 'x');
      expect(r.name, 'n');
      expect(r.principles, ['a', '1', 'true']);
      expect(r.tools, ['42', 'b']);
    });

    test('role is a regular field (multiple agents can share role)', () {
      // 同 role 的两个 agent 是不同个体（id 不同）
      const a = AgentCore(id: 'ios-lin', name: 'ios', displayName: '林', role: 'iOS');
      const b = AgentCore(id: 'ios-junior', name: 'ios', displayName: '小李', role: 'iOS');
      expect(a.role, b.role);
      expect(a.id, isNot(b.id));
    });
  });

  group('AgentMemory', () {
    test('toJson/fromJson round-trip with all fields', () {
      const m = AgentMemory(
        index: '# MEMORY index',
        shortTerm: '近期: 任务 X 进行中',
        longTerm: [
          MemoryEntry('recap-2026-07.md', '# 7 月总结\n- 学了 APM'),
          MemoryEntry('patterns/swift-concurrency.md', 'actor 模式心得'),
        ],
      );
      final j = m.toJson();
      expect(j['index'], '# MEMORY index');
      expect(j['shortTerm'], '近期: 任务 X 进行中');
      expect((j['longTerm'] as List).length, 2);
      expect((j['longTerm'] as List).first['path'], 'recap-2026-07.md');

      final r = AgentMemory.fromJson(j);
      expect(r.index, '# MEMORY index');
      expect(r.shortTerm, '近期: 任务 X 进行中');
      expect(r.longTerm.length, 2);
      expect(r.longTerm[0].path, 'recap-2026-07.md');
      expect(r.longTerm[0].content, '# 7 月总结\n- 学了 APM');
      expect(r.longTerm[1].path, 'patterns/swift-concurrency.md');
      expect(r.longTerm[1].content, 'actor 模式心得');
    });

    test('fromJson with empty map yields defaults', () {
      final r = AgentMemory.fromJson({});
      expect(r.index, '');
      expect(r.shortTerm, '');
      expect(r.longTerm, isEmpty);
    });

    test('const constructor supports default empty', () {
      const m = AgentMemory();
      expect(m.index, '');
      expect(m.shortTerm, '');
      expect(m.longTerm, isEmpty);
    });
  });

  group('AgentMeta', () {
    test('default version is 1', () {
      const m = AgentMeta();
      expect(m.version, 1);
    });

    test('toJson/fromJson round-trip', () {
      const m = AgentMeta(version: 5);
      final j = m.toJson();
      expect(j['version'], 5);
      final r = AgentMeta.fromJson(j);
      expect(r.version, 5);
    });

    test('fromJson with empty map yields default version', () {
      final r = AgentMeta.fromJson({});
      expect(r.version, 1);
    });

    test('fromJson version coerces num to int', () {
      final r = AgentMeta.fromJson({'version': 7});
      expect(r.version, 7);
    });
  });
}
