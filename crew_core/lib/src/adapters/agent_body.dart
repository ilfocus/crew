// crew_core/lib/src/adapters/agent_body.dart
import '../models/agent_spec.dart';

String renderAgentBody(AgentSpec s) {
  final b = StringBuffer();
  b.writeln('你是 **${s.displayName}**，${s.role}。');
  b.writeln();
  if (s.repos.isNotEmpty) {
    b.writeln('负责目录：${s.repos.join('、')}');
    b.writeln();
  }
  void section(String title, String body) {
    if (body.trim().isEmpty) return;
    b.writeln('## $title');
    b.writeln(body.trim());
    b.writeln();
  }

  void bulletSection(String title, List<String> items) {
    if (items.isEmpty) return;
    b.writeln('## $title');
    for (final item in items) {
      b.writeln('- $item');
    }
    b.writeln();
  }

  // 1. 人格与判断标准（IDENTITY 维度）
  section('人格', s.personality);
  bulletSection('判断标准', s.principles);

  // 2. 项目坐标/模块/技术栈/SDK/重难点/关键文件/数据流
  section('项目坐标', s.coordinates);
  section('模块结构', s.moduleStructure);
  bulletSection('技术栈', s.techStack);
  bulletSection('SDK / 三方库', s.sdks);
  bulletSection('重难点', s.difficulties);
  if (s.keyFiles.isNotEmpty) {
    b.writeln('## 关键文件');
    for (final k in s.keyFiles) {
      b.writeln('- `${k.path}` — ${k.purpose}');
    }
    b.writeln();
  }
  section('数据流', s.dataflow);

  // 3. 成长约定（固定文案，恒在）
  b.writeln('## 成长约定');
  b.writeln();
  b.writeln('### 开工召回');
  b.writeln('1. 读 `memory/${s.name}/MEMORY.md` 了解记忆结构。');
  b.writeln('2. 遇到问题时，用症状关键词 grep `memory/${s.name}/solved/`，找相似问题的解决记录。');
  b.writeln('3. 再 grep `memory/${s.name}/playbooks/`，看是否有现成套路可直接执行。');
  b.writeln('4. 命中即复用/秒解；未命中再动手排查。');
  b.writeln();
  b.writeln('### 收工蒸馏');
  b.writeln('1. 新问题解决后，按 `solved/README.md` 模板写一条记录到 `memory/${s.name}/solved/`。');
  b.writeln('2. 新事实（技术栈变更、目录调整等）更新 `memory/${s.name}/project-notes.md`。');
  b.writeln('3. 某类问题出现 ≥2 次，提炼一条 playbook 到 `memory/${s.name}/playbooks/`。');
  b.writeln('4. 更新 `memory/${s.name}/MEMORY.md` 索引指针。');
  b.writeln('5. 过时或错误的记忆及时改或删。');
  b.writeln();

  // 4. 记忆 + 工作约定
  section('记忆', s.memoryConvention);
  if (s.conventions.isNotEmpty) {
    b.writeln('## 工作约定');
    for (final c in s.conventions) {
      b.writeln('- $c');
    }
    b.writeln();
  }
  return b.toString().trimRight() + '\n';
}
