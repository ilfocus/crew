// crew_core/test/models/agent_spec_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  test('AgentSpec.fromProbeJson maps fields and injects identity', () {
    final json = {
      'role': 'iOS 端 APM SDK 工程师',
      'coordinates': '路径 ~/bm_app/ios，主工程 BitMart.xcworkspace',
      'moduleStructure': 'Core/ 单例；Plugin/ 各监控插件',
      'keyFiles': [
        {'path': 'Core/BMApm.swift:279', 'purpose': '上报总线'},
      ],
      'dataflow': '采集 → 神策 → platform',
      'memoryConvention': '开工前读 MEMORY.md',
      'conventions': ['默认在 develop/apm 工作'],
    };

    final spec = AgentSpec.fromProbeJson(
      json,
      name: 'ios',
      displayName: '小i',
      repos: ['~/bm_app/ios'],
    );

    expect(spec.name, 'ios');
    expect(spec.displayName, '小i');
    expect(spec.repos, ['~/bm_app/ios']);
    expect(spec.role, 'iOS 端 APM SDK 工程师');
    expect(spec.keyFiles.single.path, 'Core/BMApm.swift:279');
    expect(spec.keyFiles.single.purpose, '上报总线');
    expect(spec.conventions, ['默认在 develop/apm 工作']);
  });

  test('AgentSpec.fromProbeJson tolerates missing optional fields', () {
    final spec = AgentSpec.fromProbeJson(
      {'role': 'x'},
      name: 'y',
      displayName: 'z',
      repos: const [],
    );
    expect(spec.keyFiles, isEmpty);
    expect(spec.conventions, isEmpty);
    expect(spec.coordinates, '');
  });

  // --- 新增：新字段 probe 解析 ---
  test('fromProbeJson parses new fields when present', () {
    final json = {
      'role': 'iOS 开发',
      'personality': '严谨细致',
      'principles': ['不引入未测试依赖', '主线程不做 IO'],
      'techStack': ['Swift', 'SwiftUI'],
      'sdks': ['SensorsSDK', 'Firebase'],
      'difficulties': ['启动耗时分拆', '线程安全'],
      'source': 'opensource',
      'github': 'https://github.com/foo/bar',
    };
    final spec = AgentSpec.fromProbeJson(
      json,
      name: 'ios',
      displayName: '小i',
      repos: const [],
    );
    expect(spec.personality, '严谨细致');
    expect(spec.principles, ['不引入未测试依赖', '主线程不做 IO']);
    expect(spec.techStack, ['Swift', 'SwiftUI']);
    expect(spec.sdks, ['SensorsSDK', 'Firebase']);
    expect(spec.difficulties, ['启动耗时分拆', '线程安全']);
    expect(spec.source, 'opensource');
    expect(spec.github, 'https://github.com/foo/bar');
  });

  test('fromProbeJson new fields default when absent (no regression)', () {
    final spec = AgentSpec.fromProbeJson(
      {'role': 'x'},
      name: 'y',
      displayName: 'z',
      repos: const [],
    );
    expect(spec.personality, '');
    expect(spec.principles, isEmpty);
    expect(spec.techStack, isEmpty);
    expect(spec.sdks, isEmpty);
    expect(spec.difficulties, isEmpty);
    expect(spec.source, 'private');
    expect(spec.github, '');
  });

  // --- 新增：toJson/fromJson 往返 ---
  test('toJson -> fromJson round-trips all fields losslessly', () {
    const original = AgentSpec(
      name: 'ios',
      displayName: '小i',
      repos: ['~/bm_app/ios'],
      role: 'iOS 开发工程师',
      coordinates: '路径 ~/bm_app/ios',
      moduleStructure: 'Core/ 单例',
      keyFiles: [KeyFile('Core/BMApm.swift:279', '上报总线')],
      dataflow: '采集 → 神策',
      memoryConvention: '开工前读 MEMORY.md',
      conventions: ['默认在 develop/apm 工作'],
      personality: '严谨',
      principles: ['不引入未测试依赖'],
      techStack: ['Swift', 'SwiftUI'],
      sdks: ['SensorsSDK'],
      difficulties: ['线程安全'],
      source: 'opensource',
      github: 'https://github.com/foo/bar',
    );
    final json = original.toJson();
    final restored = AgentSpec.fromJson(json);

    expect(restored.name, original.name);
    expect(restored.displayName, original.displayName);
    expect(restored.repos, original.repos);
    expect(restored.role, original.role);
    expect(restored.coordinates, original.coordinates);
    expect(restored.moduleStructure, original.moduleStructure);
    expect(restored.keyFiles.length, 1);
    expect(restored.keyFiles.first.path, 'Core/BMApm.swift:279');
    expect(restored.keyFiles.first.purpose, '上报总线');
    expect(restored.dataflow, original.dataflow);
    expect(restored.memoryConvention, original.memoryConvention);
    expect(restored.conventions, original.conventions);
    expect(restored.personality, '严谨');
    expect(restored.principles, ['不引入未测试依赖']);
    expect(restored.techStack, ['Swift', 'SwiftUI']);
    expect(restored.sdks, ['SensorsSDK']);
    expect(restored.difficulties, ['线程安全']);
    expect(restored.source, 'opensource');
    expect(restored.github, 'https://github.com/foo/bar');
  });

  test('fromJson with minimal data defaults new fields', () {
    final spec = AgentSpec.fromJson({
      'name': 'x',
      'displayName': 'y',
      'repos': <String>[],
    });
    expect(spec.role, '');
    expect(spec.personality, '');
    expect(spec.principles, isEmpty);
    expect(spec.techStack, isEmpty);
    expect(spec.sdks, isEmpty);
    expect(spec.difficulties, isEmpty);
    expect(spec.source, 'private');
    expect(spec.github, '');
  });

  test('KeyFile toJson/fromJson round-trip', () {
    const k = KeyFile('foo.swift:42', '入口');
    final j = k.toJson();
    expect(j, {'path': 'foo.swift:42', 'purpose': '入口'});
    final restored = KeyFile.fromJson(j);
    expect(restored.path, 'foo.swift:42');
    expect(restored.purpose, '入口');
  });
}
