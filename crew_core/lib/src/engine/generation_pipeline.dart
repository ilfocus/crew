import '../analysis/repo_analyzer.dart';
import '../models/agent.dart';
import '../models/agent_spec.dart';
import '../models/agent_template.dart';
import '../models/crew_config.dart';
import '../models/file_artifact.dart';
import '../models/generation_result.dart';
import '../models/team_profile.dart';
import '../runner/probe_parser.dart';
import '../runner/runner.dart';
import '../templates/builtin_templates.dart';
import '../adapters/output_adapter.dart';
import 'write_planner.dart';

class GenerationPipeline {
  final Runner runner;
  final List<OutputAdapter> adapters;
  final RepoAnalyzer analyzer;
  final WritePlanner planner;

  /// 模板解析器：把 agent 的 `templateRef` 解析成 [AgentTemplate]。
  /// 默认只认内置库；GUI/CLI 传入包含自定义模板的 resolver。
  final AgentTemplate? Function(String ref) resolveTemplate;

  GenerationPipeline({
    required this.runner,
    required this.adapters,
    RepoAnalyzer? analyzer,
    WritePlanner? planner,
    AgentTemplate? Function(String ref)? resolve,
  })  : analyzer = analyzer ?? RepoAnalyzer(),
        planner = planner ?? WritePlanner(),
        resolveTemplate = resolve ?? templateByRef;

  Future<List<AssignmentCandidate>> analyze(CrewConfig config) async {
    return analyzer.suggest(
      kBuiltinTemplates,
      config.repos.map((r) => r.path).toList(),
    );
  }

  Future<List<AgentSpec>> probe(
    CrewConfig config, {
    AgentTemplate? Function(String ref)? resolve,
  }) async {
    final allPaths = config.repos.map((r) => r.path).toList();
    final resolver = resolve ?? resolveTemplate;
    final specs = <AgentSpec>[];
    for (final agent in config.agents) {
      final template = resolver(agent.templateRef);
      if (template == null) {
        throw StateError('未知模板：${agent.templateRef}');
      }
      final repos = agent.isAllRepos ? allPaths : agent.repos;
      final workingDir = repos.isNotEmpty ? repos.first : '.';
      final result = await runner.probe(
        workingDir: workingDir,
        prompt: template.probePrompt,
        template: template,
      );
      if (!result.ok) {
        throw StateError('探查失败(${agent.name})：exit ${result.exitCode}');
      }
      specs.add(parseProbe(
        result.rawOutput,
        name: agent.name,
        displayName: template.displayName,
        repos: repos,
      ));
    }
    return specs;
  }

  TeamProfile synthesize(CrewConfig config, List<AgentSpec> specs) =>
      TeamProfile(name: config.name, members: specs);

  Future<GenerationResult> generate(
    CrewConfig config, {
    AgentTemplate? Function(String ref)? resolve,
  }) async {
    final specs = await probe(config, resolve: resolve);
    return GenerationResult(
      config: config,
      specs: specs,
      team: synthesize(config, specs),
    );
  }

  List<FileArtifact> renderAll(GenerationResult result) {
    final arts = <FileArtifact>[];
    for (final a in adapters) {
      arts.addAll(a.render(result));
    }
    arts.add(FileArtifact('crew.yaml', result.config.toYaml()));
    return arts;
  }

  WritePlan planWrites(String root, GenerationResult result) =>
      planner.plan(root, renderAll(result));

  Future<void> emit(String root, GenerationResult result) async {
    await planner.apply(root, planWrites(root, result));
  }
}
