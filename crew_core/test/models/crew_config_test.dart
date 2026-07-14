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
}
