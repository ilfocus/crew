// crew_core/lib/src/templates/builtin_templates.dart
import '../models/agent_template.dart';

const String _probeCommon = '''
探查这个代码目录，产出该专家 agent 的结构化画像。只输出一个 JSON 对象，字段：
role(一句话职责)、coordinates(项目坐标：主工程/关键路径/分支/技术栈)、
moduleStructure(模块结构说明)、keyFiles(数组，每项 {path, purpose}，path 尽量带行号)、
dataflow(在系统中的位置与上下游关系)、memoryConvention(记忆读写约定)、
conventions(字符串数组，工作约定)。不要输出 JSON 以外的任何内容。
''';

const List<AgentTemplate> kBuiltinTemplates = [
  AgentTemplate(
    id: 'ios-dev', version: 1, defaultName: 'ios', displayName: '小i',
    role: 'iOS 开发工程师',
    probePrompt: '你是资深 iOS 工程师。$_probeCommon',
    matchGlobs: ['*.xcworkspace', '*.xcodeproj', 'Podfile', '*.swift'],
  ),
  AgentTemplate(
    id: 'android-dev', version: 1, defaultName: 'android', displayName: '小安',
    role: 'Android 开发工程师',
    probePrompt: '你是资深 Android 工程师。$_probeCommon',
    matchGlobs: ['build.gradle', 'build.gradle.kts', 'settings.gradle', '*.kt'],
  ),
  AgentTemplate(
    id: 'frontend', version: 1, defaultName: 'frontend', displayName: '小前',
    role: '前端开发工程师',
    probePrompt: '你是资深前端工程师。$_probeCommon',
    matchGlobs: ['package.json', 'vite.config.*', 'tsconfig.json', 'index.html'],
  ),
  AgentTemplate(
    id: 'backend', version: 1, defaultName: 'backend', displayName: '小后',
    role: '后端开发工程师',
    probePrompt: '你是资深后端工程师。$_probeCommon',
    matchGlobs: ['go.mod', 'pom.xml', 'Cargo.toml', 'src/main'],
  ),
  AgentTemplate(
    id: 'python', version: 1, defaultName: 'python', displayName: '小P',
    role: 'Python 工程师',
    probePrompt: '你是资深 Python 工程师。$_probeCommon',
    matchGlobs: ['requirements.txt', 'pyproject.toml', 'setup.py', '*.py'],
  ),
  AgentTemplate(
    id: 'pm', version: 1, defaultName: 'pm', displayName: '产品',
    role: '产品经理',
    probePrompt:
        '你是产品经理，负责全局理解与协调。综合所有关联目录，$_probeCommon',
    matchGlobs: [],
  ),
];

AgentTemplate? templateByRef(String ref) {
  for (final t in kBuiltinTemplates) {
    if (t.ref == ref) return t;
  }
  return null;
}
