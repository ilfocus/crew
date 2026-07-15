// crew_core/test/models/crew_config_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  final config = CrewConfig(
    version: 1,
    name: 'apm',
    createdAt: '2026-07-13',
    repos: const [Repo('~/bm_app/ios'), Repo('~/bm_app/android')],
    targets: const ['claude', 'codex'],
    runner: 'cli',
    agents: const [
      Agent(name: 'ios', templateRef: 'ios-dev@1', repos: ['~/bm_app/ios']),
      Agent(name: 'pm', templateRef: 'pm@1', repos: [kAllRepos]),
    ],
  );

  test('toYaml then fromYaml round-trips', () {
    final restored = CrewConfig.fromYaml(config.toYaml());
    expect(restored.name, 'apm');
    expect(restored.createdAt, '2026-07-13');
    expect(restored.repos.map((r) => r.path),
        ['~/bm_app/ios', '~/bm_app/android']);
    expect(restored.targets, ['claude', 'codex']);
    expect(restored.runner, 'cli');
    expect(restored.agents.length, 2);
    expect(restored.agents.last.repos, [kAllRepos]);
  });

  test('toYaml emits a version header', () {
    expect(config.toYaml(), contains('version: 1'));
  });

  test('cliTool defaults to claude and round-trips through yaml', () {
    expect(config.cliTool, 'claude');
    final codex = CrewConfig(
      version: 1, name: 'apm', createdAt: '2026-07-13',
      repos: const [Repo('~/x')], targets: const ['codex'],
      runner: 'cli', cliTool: 'codex', agents: const [],
    );
    expect(codex.toYaml(), contains('cliTool: codex'));
    expect(CrewConfig.fromYaml(codex.toYaml()).cliTool, 'codex');
  });

  test('fromYaml defaults cliTool to claude when absent (back-compat)', () {
    const legacy = 'version: 1\nname: apm\ncreatedAt: 2026-07-13\n'
        'repos:\n  - path: ~/x\ntargets: [claude]\nrunner: cli\nagents:\n';
    expect(CrewConfig.fromYaml(legacy).cliTool, 'claude');
  });
}
