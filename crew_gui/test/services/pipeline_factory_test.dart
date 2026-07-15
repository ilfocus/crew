import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/services/pipeline_factory.dart';
import 'package:flutter_test/flutter_test.dart';

CrewConfig _config({required String cliTool, required String templateRef}) =>
    CrewConfig(
      version: 1,
      name: 'apm',
      createdAt: '2026-07-13',
      repos: const [Repo('~/x')],
      targets: const ['claude'],
      runner: 'cli',
      cliTool: cliTool,
      agents: [Agent(name: 'a', templateRef: templateRef, repos: const ['~/x'])],
    );

void main() {
  test('buildPipeline builds a CliRunner honoring config.cliTool', () {
    final pipeline = buildPipeline(
      _config(cliTool: 'codex', templateRef: 'ios-dev@1'),
      resolve: templateByRef,
    );
    expect(pipeline.runner, isA<CliRunner>());
    expect((pipeline.runner as CliRunner).tool, 'codex');
  });

  test('buildPipeline threads the resolver so custom templates resolve', () {
    const custom = AgentTemplate(
      id: 'data-eng', version: 1, defaultName: 'data', displayName: '小数',
      role: '数据工程师', probePrompt: 'p', matchGlobs: [],
    );
    final pipeline = buildPipeline(
      _config(cliTool: 'claude', templateRef: custom.ref),
      resolve: (ref) => ref == custom.ref ? custom : templateByRef(ref),
    );
    expect(pipeline.resolveTemplate('data-eng@1')?.displayName, '小数');
  });
}
