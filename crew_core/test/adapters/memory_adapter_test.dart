// crew_core/test/adapters/memory_adapter_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  const spec = AgentSpec(
    name: 'ios', displayName: '小i', repos: ['~/bm_app/ios'], role: 'iOS 开发',
    coordinates: '', moduleStructure: '', keyFiles: [], dataflow: '',
    memoryConvention: '', conventions: [],
    techStack: ['Swift', 'SwiftUI'],
    sdks: ['SensorsSDK'],
    difficulties: ['线程安全'],
  );
  const spec2 = AgentSpec(
    name: 'pm', displayName: '产品', repos: ['~/bm_app/ios'], role: '产品经理',
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
    specs: const [spec, spec2],
    team: const TeamProfile(name: 'apm', members: [spec, spec2]),
  );

  test('emits 4 memory files per spec, all flagged isMemory', () {
    final arts = MemoryAdapter().render(result);
    final paths = arts.map((a) => a.relativePath).toSet();
    // 2 specs × 4 files = 8
    expect(paths, containsAll({
      'memory/ios/MEMORY.md',
      'memory/ios/project-notes.md',
      'memory/ios/solved/README.md',
      'memory/ios/playbooks/README.md',
      'memory/pm/MEMORY.md',
      'memory/pm/project-notes.md',
      'memory/pm/solved/README.md',
      'memory/pm/playbooks/README.md',
    }));
    expect(arts.every((a) => a.isMemory), isTrue);
  });

  test('MEMORY.md contains recall usage (grep/症状/召回)', () {
    final arts = MemoryAdapter().render(result);
    final mem = arts.firstWhere((a) => a.relativePath == 'memory/ios/MEMORY.md');
    expect(mem.content, contains('召回'));
    expect(mem.content, contains('grep'));
    expect(mem.content, contains('症状'));
    expect(mem.content, contains('project-notes.md'));
    expect(mem.content, contains('solved/'));
    expect(mem.content, contains('playbooks/'));
    expect(mem.content, contains('收工蒸馏'));
  });

  test('solved/README.md contains frontmatter fields', () {
    final arts = MemoryAdapter().render(result);
    final solved =
        arts.firstWhere((a) => a.relativePath == 'memory/ios/solved/README.md');
    expect(solved.content, contains('症状'));
    expect(solved.content, contains('关键词'));
    expect(solved.content, contains('根因'));
    expect(solved.content, contains('解法'));
    expect(solved.content, contains('source'));
  });

  test('playbooks/README.md contains playbook structure', () {
    final arts = MemoryAdapter().render(result);
    final pb = arts.firstWhere(
        (a) => a.relativePath == 'memory/ios/playbooks/README.md');
    expect(pb.content, contains('套路'));
    expect(pb.content, contains('何时用'));
    expect(pb.content, contains('步骤'));
    expect(pb.content, contains('来自'));
  });

  test('project-notes.md includes techStack/sdks/difficulties when present', () {
    final arts = MemoryAdapter().render(result);
    final notes = arts.firstWhere(
        (a) => a.relativePath == 'memory/ios/project-notes.md');
    expect(notes.content, contains('Swift'));
    expect(notes.content, contains('SensorsSDK'));
    expect(notes.content, contains('线程安全'));
  });

  test('project-notes.md omits techStack section when empty', () {
    final arts = MemoryAdapter().render(result);
    final notes = arts.firstWhere(
        (a) => a.relativePath == 'memory/pm/project-notes.md');
    expect(notes.content, isNot(contains('技术栈')));
    expect(notes.content, contains('~/bm_app/ios'));
  });
}
