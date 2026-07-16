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
  personality: '严谨细致，追求稳定',
  principles: ['不引入未测试依赖', '主线程不做 IO'],
  techStack: ['Swift', 'SwiftUI', 'Combine'],
  sdks: ['SensorsSDK', 'Firebase'],
  difficulties: ['启动耗时分拆', '线程安全'],
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
    expect(body, isNot(contains('## 人格')));
    expect(body, isNot(contains('## 判断标准')));
    expect(body, isNot(contains('## 技术栈')));
    expect(body, isNot(contains('## SDK')));
    expect(body, isNot(contains('## 重难点')));
  });

  // --- 新增：新维度渲染 ---
  test('body includes personality and principles sections', () {
    final body = renderAgentBody(_spec);
    expect(body, contains('## 人格'));
    expect(body, contains('严谨细致，追求稳定'));
    expect(body, contains('## 判断标准'));
    expect(body, contains('不引入未测试依赖'));
    expect(body, contains('主线程不做 IO'));
  });

  test('body includes techStack, sdks, difficulties sections', () {
    final body = renderAgentBody(_spec);
    expect(body, contains('## 技术栈'));
    expect(body, contains('Swift'));
    expect(body, contains('SwiftUI'));
    expect(body, contains('## SDK / 三方库'));
    expect(body, contains('SensorsSDK'));
    expect(body, contains('## 重难点'));
    expect(body, contains('启动耗时分拆'));
    expect(body, contains('线程安全'));
  });

  // --- 成长约定恒在 ---
  test('body always contains growth convention section', () {
    final body = renderAgentBody(_spec);
    expect(body, contains('## 成长约定'));
    expect(body, contains('开工召回'));
    expect(body, contains('收工蒸馏'));
    expect(body, contains('solved'));
    expect(body, contains('playbooks'));
    expect(body, contains('grep'));
    expect(body, contains('memory/ios/MEMORY.md'));
  });

  test('growth convention present even for bare spec', () {
    const bare = AgentSpec(
      name: 'x', displayName: 'X', repos: [], role: 'r',
      coordinates: '', moduleStructure: '', keyFiles: [], dataflow: '',
      memoryConvention: '', conventions: [],
    );
    final body = renderAgentBody(bare);
    expect(body, contains('## 成长约定'));
    expect(body, contains('开工召回'));
    expect(body, contains('收工蒸馏'));
    expect(body, contains('memory/x/solved/'));
    expect(body, contains('memory/x/playbooks/'));
  });
}
