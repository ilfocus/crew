// crew_core/test/adapters/agent_body_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

const _spec = AgentSpec(
  name: 'ios', displayName: '小i', repos: ['~/bm_app/ios'],
  role: 'iOS 开发工程师',
  coordinates: '路径 ~/bm_app/ios',
  moduleStructure: 'Core/ 单例',
  keyFiles: [KeyFile('Core/BMApm.swift:279', '上报总线')],
  dataflow: '采集 → 神策 → platform',
  memoryConvention: '开工前读 MEMORY.md',
  conventions: ['默认在 develop/apm 工作'],
);

void main() {
  test('body includes displayName, role and all populated sections', () {
    final body = renderAgentBody(_spec);
    expect(body, contains('小i'));
    expect(body, contains('iOS 开发工程师'));
    expect(body, contains('## 项目坐标'));
    expect(body, contains('路径 ~/bm_app/ios'));
    expect(body, contains('Core/BMApm.swift:279'));
    expect(body, contains('上报总线'));
    expect(body, contains('## 工作约定'));
    expect(body, contains('默认在 develop/apm 工作'));
  });

  test('empty sections are omitted', () {
    const bare = AgentSpec(
      name: 'x', displayName: 'X', repos: [], role: 'r',
      coordinates: '', moduleStructure: '', keyFiles: [], dataflow: '',
      memoryConvention: '', conventions: [],
    );
    final body = renderAgentBody(bare);
    expect(body, isNot(contains('## 项目坐标')));
    expect(body, isNot(contains('## 关键文件')));
  });
}
