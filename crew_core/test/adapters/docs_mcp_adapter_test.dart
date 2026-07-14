import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

GenerationResult _r() {
  const ios = AgentSpec(
    name: 'ios', displayName: '小i', repos: ['~/bm_app/ios'], role: 'iOS 开发',
    coordinates: '', moduleStructure: '', keyFiles: [], dataflow: '',
    memoryConvention: '', conventions: [],
  );
  const pm = AgentSpec(
    name: 'pm', displayName: '产品', repos: ['~/bm_app/ios'], role: '产品经理',
    coordinates: '', moduleStructure: '', keyFiles: [], dataflow: '',
    memoryConvention: '', conventions: [],
  );
  return GenerationResult(
    config: CrewConfig(
      version: 1, name: 'apm', createdAt: '2026-07-13',
      repos: const [Repo('~/bm_app/ios')], targets: const ['claude'],
      runner: 'cli',
      agents: const [
        Agent(name: 'ios', templateRef: 'ios-dev@1', repos: ['~/bm_app/ios']),
        Agent(name: 'pm', templateRef: 'pm@1', repos: [kAllRepos]),
      ],
    ),
    specs: const [ios, pm],
    team: const TeamProfile(name: 'apm', members: [ios, pm]),
  );
}

void main() {
  test('DocsAdapter emits three team docs listing members', () {
    final arts = DocsAdapter().render(_r());
    final byPath = {for (final a in arts) a.relativePath: a.content};
    expect(byPath.keys, containsAll({'CLAUDE.md', 'AGENTS.md', 'ONBOARDING.md'}));
    expect(byPath['CLAUDE.md'], contains('apm'));
    expect(byPath['CLAUDE.md'], contains('小i'));
    expect(byPath['CLAUDE.md'], contains('产品'));
  });

  test('McpAdapter emits .mcp.json with empty servers', () {
    final arts = McpAdapter().render(_r());
    final mcp = arts.firstWhere((a) => a.relativePath == '.mcp.json');
    expect(mcp.content, contains('mcpServers'));
  });
}
