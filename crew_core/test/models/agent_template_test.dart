// crew_core/test/models/agent_template_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  test('AgentTemplate.ref combines id and version', () {
    const t = AgentTemplate(
      id: 'ios-dev',
      version: 1,
      defaultName: 'ios',
      displayName: '小i',
      role: 'iOS 开发',
      probePrompt: '探查 iOS 工程',
      matchGlobs: ['*.xcworkspace', 'Podfile'],
    );
    expect(t.ref, 'ios-dev@1');
  });

  test('Agent.isAllRepos detects the <all> sentinel', () {
    const pm = Agent(name: 'pm', templateRef: 'pm@1', repos: [kAllRepos]);
    const ios = Agent(name: 'ios', templateRef: 'ios-dev@1', repos: ['~/x']);
    expect(pm.isAllRepos, isTrue);
    expect(ios.isAllRepos, isFalse);
  });

  // --- 新增：人设字段 ---
  test('AgentTemplate has personality and principles with defaults', () {
    const t = AgentTemplate(
      id: 'x', version: 1, defaultName: 'x', displayName: 'X',
      role: 'r', probePrompt: 'p', matchGlobs: [],
    );
    expect(t.personality, '');
    expect(t.principles, isEmpty);
  });

  test('AgentTemplate constructed with personality and principles', () {
    const t = AgentTemplate(
      id: 'x', version: 1, defaultName: 'x', displayName: 'X',
      role: 'r', probePrompt: 'p', matchGlobs: [],
      personality: '严谨',
      principles: ['不引入未测试依赖', '主线程不做 IO'],
    );
    expect(t.personality, '严谨');
    expect(t.principles, ['不引入未测试依赖', '主线程不做 IO']);
  });

  test('all builtin templates have non-empty personality and principles', () {
    for (final t in kBuiltinTemplates) {
      expect(t.personality, isNotEmpty, reason: '${t.id} personality should be non-empty');
      expect(t.principles, isNotEmpty, reason: '${t.id} principles should be non-empty');
    }
  });
}
