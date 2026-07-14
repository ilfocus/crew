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

  section('项目坐标', s.coordinates);
  section('模块结构', s.moduleStructure);
  if (s.keyFiles.isNotEmpty) {
    b.writeln('## 关键文件');
    for (final k in s.keyFiles) {
      b.writeln('- `${k.path}` — ${k.purpose}');
    }
    b.writeln();
  }
  section('数据流', s.dataflow);
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
