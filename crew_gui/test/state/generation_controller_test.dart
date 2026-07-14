// crew_gui/test/state/generation_controller_test.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/services/pipeline_factory.dart';
import 'package:crew_gui/state/generation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adaptersFor gates claude/codex adapters by targets', () {
    final claudeOnly = adaptersFor({'claude'}).map((a) => a.target).toSet();
    expect(claudeOnly, containsAll({'claude', 'memory', 'docs', 'mcp'}));
    expect(claudeOnly.contains('codex'), isFalse);
    expect(adaptersFor({'codex'}).map((a) => a.target), contains('codex'));
  });

  test('generateAndPlan then confirmAndEmit writes the workspace', () async {
    final root = Directory.systemTemp.createTempSync('ws');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/ios').createSync();

    final config = CrewConfig(
      version: 1, name: 'apm', createdAt: '2026-07-13',
      repos: [Repo('${root.path}/ios')], targets: const ['claude'], runner: 'cli',
      agents: [Agent(name: 'ios', templateRef: 'ios-dev@1', repos: ['${root.path}/ios'])],
    );

    final fake = FakeRunner((dir, t) =>
        '{"role":"${t.role}","coordinates":"c","moduleStructure":"m","keyFiles":[],"dataflow":"","memoryConvention":"","conventions":[]}');

    final ctrl = GenerationController(
      pipelineFactory: (c) => GenerationPipeline(
        runner: fake, adapters: adaptersFor(c.targets.toSet())),
    );

    await ctrl.generateAndPlan(root.path, config);
    expect(ctrl.status, GenStatus.planned);
    expect(ctrl.plan!.writes.isNotEmpty, isTrue);

    await ctrl.confirmAndEmit(root.path);
    expect(ctrl.status, GenStatus.done);
    expect(File('${root.path}/.claude/agents/ios.md').existsSync(), isTrue);
    expect(File('${root.path}/crew.yaml').existsSync(), isTrue);
  });

  test('sets error status when pipeline throws', () async {
    final ctrl = GenerationController(
      pipelineFactory: (c) => GenerationPipeline(
        runner: FakeRunner((d, t) => 'not json'),
        adapters: adaptersFor(c.targets.toSet())),
    );
    final config = CrewConfig(
      version: 1, name: 'x', createdAt: '2026-07-13',
      repos: const [Repo('/x')], targets: const ['claude'], runner: 'cli',
      agents: const [Agent(name: 'ios', templateRef: 'ios-dev@1', repos: ['/x'])],
    );
    await ctrl.generateAndPlan('/tmp/does-not-matter', config);
    expect(ctrl.status, GenStatus.error);
    expect(ctrl.error, isNotNull);
  });
}
