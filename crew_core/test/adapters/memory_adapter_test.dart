// crew_core/test/adapters/memory_adapter_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  const spec = AgentSpec(
    name: 'ios', displayName: '小i', repos: ['~/bm_app/ios'], role: 'iOS 开发',
    coordinates: '', moduleStructure: '', keyFiles: [], dataflow: '',
    memoryConvention: '', conventions: [],
  );
  final result = GenerationResult(
    config: CrewConfig(
      version: 1, name: 'apm', createdAt: '2026-07-13',
      repos: const [Repo('~/bm_app/ios')], targets: const ['claude'],
      runner: 'cli',
      agents: const [Agent(name: 'ios', templateRef: 'ios-dev@1', repos: ['~/bm_app/ios'])],
    ),
    specs: const [spec],
    team: const TeamProfile(name: 'apm', members: [spec]),
  );

  test('emits MEMORY.md and project-notes.md, both flagged isMemory', () {
    final arts = MemoryAdapter().render(result);
    final paths = arts.map((a) => a.relativePath).toSet();
    expect(paths, containsAll({
      'memory/ios/MEMORY.md',
      'memory/ios/project-notes.md',
    }));
    expect(arts.every((a) => a.isMemory), isTrue);
    final notes = arts.firstWhere((a) => a.relativePath.endsWith('project-notes.md'));
    expect(notes.content, contains('~/bm_app/ios'));
  });
}
