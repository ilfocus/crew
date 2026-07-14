// crew_core/test/adapters/claude_codex_adapter_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

GenerationResult _result() {
  const spec = AgentSpec(
    name: 'ios', displayName: '小i', repos: ['~/bm_app/ios'],
    role: 'iOS 开发工程师', coordinates: '路径 ~/bm_app/ios',
    moduleStructure: 'Core/ 单例', keyFiles: [], dataflow: '',
    memoryConvention: '', conventions: [],
  );
  final config = CrewConfig(
    version: 1, name: 'apm', createdAt: '2026-07-13',
    repos: const [Repo('~/bm_app/ios')], targets: const ['claude', 'codex'],
    runner: 'cli',
    agents: const [Agent(name: 'ios', templateRef: 'ios-dev@1', repos: ['~/bm_app/ios'])],
  );
  return GenerationResult(
    config: config, specs: const [spec],
    team: const TeamProfile(name: 'apm', members: [spec]),
  );
}

void main() {
  test('ClaudeAdapter emits .claude/agents/<name>.md with frontmatter', () {
    final arts = ClaudeAdapter().render(_result());
    final md = arts.single;
    expect(md.relativePath, '.claude/agents/ios.md');
    expect(md.content, startsWith('---\n'));
    expect(md.content, contains('name: ios'));
    expect(md.content, contains('description: iOS 开发工程师'));
    expect(md.content, contains('你是 **小i**'));
  });

  test('CodexAdapter emits .codex/agents/<name>.toml', () {
    final arts = CodexAdapter().render(_result());
    final toml = arts.single;
    expect(toml.relativePath, '.codex/agents/ios.toml');
    expect(toml.content, contains('name = "ios"'));
    expect(toml.content, contains('developer_instructions = """'));
    expect(toml.content, contains('你是 **小i**'));
  });

  test('claude and codex share the same agent body (same source)', () {
    final md = ClaudeAdapter().render(_result()).single.content;
    final toml = CodexAdapter().render(_result()).single.content;
    // 正文核心句在两种格式里都出现，证明同源渲染。
    expect(md, contains('## 项目坐标'));
    expect(toml, contains('## 项目坐标'));
    expect(md, contains('路径 ~/bm_app/ios'));
    expect(toml, contains('路径 ~/bm_app/ios'));
  });
}
