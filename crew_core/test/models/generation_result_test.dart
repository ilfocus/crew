// crew_core/test/models/generation_result_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  test('FileArtifact defaults isMemory to false', () {
    const a = FileArtifact('CLAUDE.md', 'hi');
    expect(a.isMemory, isFalse);
    const m = FileArtifact('memory/ios/MEMORY.md', 'x', isMemory: true);
    expect(m.isMemory, isTrue);
  });

  test('GenerationResult holds config, specs and team', () {
    const spec = AgentSpec(
      name: 'ios', displayName: '小i', repos: ['~/x'], role: 'r',
      coordinates: '', moduleStructure: '', keyFiles: [], dataflow: '',
      memoryConvention: '', conventions: [],
    );
    final config = CrewConfig(
      version: 1, name: 'apm', createdAt: '2026-07-13',
      repos: const [Repo('~/x')], targets: const ['claude'],
      runner: 'cli',
      agents: const [Agent(name: 'ios', templateRef: 'ios-dev@1', repos: ['~/x'])],
    );
    final result = GenerationResult(
      config: config, specs: const [spec],
      team: const TeamProfile(name: 'apm', members: [spec]),
    );
    expect(result.team.members.single.name, 'ios');
    expect(result.config.name, 'apm');
  });
}
