import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

CrewConfig _config(String iosPath) => CrewConfig(
      version: 1, name: 'apm', createdAt: '2026-07-13',
      repos: [Repo(iosPath)], targets: const ['claude', 'codex'], runner: 'cli',
      agents: [
        Agent(name: 'ios', templateRef: 'ios-dev@1', repos: [iosPath]),
        const Agent(name: 'pm', templateRef: 'pm@1', repos: [kAllRepos]),
      ],
    );

void main() {
  test('generate + emit produces claude, codex, memory, docs, crew.yaml', () async {
    final root = Directory.systemTemp.createTempSync('ws');
    addTearDown(() => root.deleteSync(recursive: true));
    final iosPath = '${root.path}/ios';
    Directory(iosPath).createSync();

    // FakeRunner 按 template.role 返回一份合法探查 JSON（含能力维度字段）。
    final runner = FakeRunner((dir, t) =>
        '{"role":"${t.role}","coordinates":"路径 $dir","moduleStructure":"Core/","keyFiles":[],"dataflow":"","memoryConvention":"","conventions":[],'
        '"techStack":["Swift","SwiftUI"],"sdks":["SensorsSDK"],"difficulties":["启动耗时"]}');

    final pipeline = GenerationPipeline(
      runner: runner,
      adapters: [ClaudeAdapter(), CodexAdapter(), MemoryAdapter(), DocsAdapter(), McpAdapter()],
    );

    final config = _config(iosPath);
    final result = await pipeline.generate(config);
    expect(result.specs.length, 2); // ios + pm
    expect(result.specs.firstWhere((s) => s.name == 'pm').repos, [iosPath]); // <all> 展开

    await pipeline.emit(root.path, result);

    expect(File('${root.path}/.claude/agents/ios.md').existsSync(), isTrue);
    expect(File('${root.path}/.claude/agents/pm.md').existsSync(), isTrue);
    expect(File('${root.path}/.codex/agents/ios.toml').existsSync(), isTrue);
    expect(File('${root.path}/memory/ios/MEMORY.md').existsSync(), isTrue);
    expect(File('${root.path}/CLAUDE.md').existsSync(), isTrue);
    expect(File('${root.path}/crew.yaml').readAsStringSync(), contains('name: apm'));
  });

  test('generate resolves custom templates via the pipeline resolver', () async {
    const custom = AgentTemplate(
      id: 'data-eng', version: 1, defaultName: 'data', displayName: '小数',
      role: '数据工程师', probePrompt: 'probe', matchGlobs: [],
    );
    final runner = FakeRunner((dir, t) => '{"role":"${t.role}"}');
    // 管线携带一个能解析自定义 ref 的 resolver（内置库并不认识 data-eng@1）。
    final pipeline = GenerationPipeline(
      runner: runner,
      adapters: const [],
      resolve: (ref) => ref == custom.ref ? custom : templateByRef(ref),
    );
    final config = CrewConfig(
      version: 1, name: 'x', createdAt: '2026-07-13',
      repos: const [Repo('~/data')], targets: const ['claude'], runner: 'cli',
      agents: const [Agent(name: 'data', templateRef: 'data-eng@1', repos: ['~/data'])],
    );

    final result = await pipeline.generate(config);
    expect(result.specs.single.role, '数据工程师');
    expect(result.specs.single.displayName, '小数');
  });

  test('analyze returns assignment candidates for the repos', () async {
    final root = Directory.systemTemp.createTempSync('ws2');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/Podfile').writeAsStringSync('');
    final pipeline = GenerationPipeline(
      runner: FakeRunner((d, t) => '{"role":"r"}'),
      adapters: const [],
    );
    final candidates = await pipeline.analyze(
      CrewConfig(version: 1, name: 'x', createdAt: '2026-07-13',
        repos: [Repo(root.path)], targets: const ['claude'], runner: 'cli',
        agents: const []),
    );
    expect(candidates.any((c) => c.templateId == 'ios-dev'), isTrue);
  });

  test('generate injects template personality + probe capabilities into spec', () async {
    final root = Directory.systemTemp.createTempSync('ws_inject');
    addTearDown(() => root.deleteSync(recursive: true));
    final iosPath = '${root.path}/ios';
    Directory(iosPath).createSync();

    // FakeRunner 返回含能力维度的探查 JSON
    final runner = FakeRunner((dir, t) =>
        '{"role":"${t.role}","coordinates":"","moduleStructure":"","keyFiles":[],'
        '"dataflow":"","memoryConvention":"","conventions":[],'
        '"techStack":["Swift","SwiftUI"],"sdks":["SensorsSDK"],"difficulties":["线程安全"]}');

    final pipeline = GenerationPipeline(
      runner: runner,
      adapters: const [],
    );

    final config = CrewConfig(
      version: 1, name: 'apm', createdAt: '2026-07-13',
      repos: [Repo(iosPath)], targets: const ['claude'], runner: 'cli',
      agents: [
        Agent(name: 'ios', templateRef: 'ios-dev@1', repos: [iosPath]),
      ],
    );

    final result = await pipeline.generate(config);
    final spec = result.specs.single;

    // 模板人设（来自 AgentTemplate 预设）
    expect(spec.personality, '严谨、重性能与体验，偏保守不冒进');
    expect(spec.principles, contains('主线程不做阻塞 IO'));

    // 探查能力（来自 probe JSON）
    expect(spec.techStack, ['Swift', 'SwiftUI']);
    expect(spec.sdks, ['SensorsSDK']);
    expect(spec.difficulties, ['线程安全']);

    // 渲染后正文含对应 section
    final body = renderAgentBody(spec);
    expect(body, contains('## 人格'));
    expect(body, contains('## 判断标准'));
    expect(body, contains('## 技术栈'));
    expect(body, contains('## SDK / 三方库'));
    expect(body, contains('## 重难点'));
  });

  test('generate with empty-personality template does not override probe values', () async {
    const custom = AgentTemplate(
      id: 'plain', version: 1, defaultName: 'plain', displayName: '小P',
      role: '通用', probePrompt: 'probe', matchGlobs: [],
      // personality 和 principles 留空
    );
    final runner = FakeRunner((dir, t) =>
        '{"role":"r","personality":"来自probe","principles":["probe原则"]}');
    final pipeline = GenerationPipeline(
      runner: runner,
      adapters: const [],
      resolve: (ref) => ref == custom.ref ? custom : templateByRef(ref),
    );
    final config = CrewConfig(
      version: 1, name: 'x', createdAt: '2026-07-13',
      repos: const [Repo('~/r')], targets: const ['claude'], runner: 'cli',
      agents: const [Agent(name: 'plain', templateRef: 'plain@1', repos: ['~/r'])],
    );
    final result = await pipeline.generate(config);
    // 模板人设为空 → 保留 probe 返回的值
    expect(result.specs.single.personality, '来自probe');
    expect(result.specs.single.principles, ['probe原则']);
  });
}
