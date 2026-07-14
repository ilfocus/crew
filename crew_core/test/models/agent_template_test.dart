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
}
