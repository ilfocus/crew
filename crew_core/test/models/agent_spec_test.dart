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
}
