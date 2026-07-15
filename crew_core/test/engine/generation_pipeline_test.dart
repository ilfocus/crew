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

    // FakeRunner 按 template.role 返回一份合法探查 JSON。
    final runner = FakeRunner((dir, t) =>
        '{"role":"${t.role}","coordinates":"路径 $dir","moduleStructure":"Core/","keyFiles":[],"dataflow":"","memoryConvention":"","conventions":[]}');

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
}
