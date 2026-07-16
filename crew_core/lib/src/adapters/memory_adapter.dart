// crew_core/lib/src/adapters/memory_adapter.dart
import '../models/file_artifact.dart';
import '../models/generation_result.dart';
import 'output_adapter.dart';

class MemoryAdapter implements OutputAdapter {
  @override
  String get target => 'memory';

  @override
  List<FileArtifact> render(GenerationResult result) {
    final out = <FileArtifact>[];
    for (final s in result.specs) {
      // 1. 召回式索引
      final index = '# ${s.displayName} 的记忆索引\n\n'
          '## 开工召回\n\n'
          '1. 先读本文件（`MEMORY.md`）了解记忆结构。\n'
          '2. 遇到问题时，用**症状关键词** grep `solved/` 目录，找到相似问题的解决记录。\n'
          '3. 再 grep `playbooks/` 目录，看是否有现成套路可直接执行。\n'
          '4. 命中即复用/秒解；未命中再动手排查。\n\n'
          '## 记忆结构\n\n'
          '- [项目笔记](project-notes.md) — 角色与关联目录、技术栈/SDK\n'
          '- [solved/](solved/README.md) — 解决过的问题（情景记忆）\n'
          '- [playbooks/](playbooks/README.md) — 套路模板（程序记忆）\n\n'
          '## 收工蒸馏\n\n'
          '1. 新问题解决后，按 `solved/README.md` 模板写一条记录。\n'
          '2. 某类问题出现 ≥2 次，提炼到 `playbooks/`。\n'
          '3. 更新本文件索引指针。\n'
          '4. 过时/错误记忆及时改或删。\n';

      // 2. 语义记忆（保留+增强）
      final notes = '---\n'
          'name: project-notes\n'
          'description: ${s.displayName}（${s.role}）的初始项目笔记\n'
          '---\n\n'
          '角色：${s.role}\n'
          '关联目录：${s.repos.join('、')}\n';
      if (s.techStack.isNotEmpty) {
        notes_buffer(StringBuffer b) {
          b.writeln('技术栈：${s.techStack.join('、')}');
          if (s.sdks.isNotEmpty) b.writeln('SDK/三方库：${s.sdks.join('、')}');
          if (s.difficulties.isNotEmpty) {
            b.writeln('重难点：');
            for (final d in s.difficulties) {
              b.writeln('- $d');
            }
          }
        }

        final buf = StringBuffer(notes);
        notes_buffer(buf);
        out.add(FileArtifact(
            'memory/${s.name}/project-notes.md', buf.toString(),
            isMemory: true));
      } else {
        out.add(FileArtifact(
            'memory/${s.name}/project-notes.md', notes,
            isMemory: true));
      }

      // 3. solved/ 情景记忆模板
      final solved = '# solved/ — 解决过的问题\n\n'
          '本目录存放每次解决问题的结构化记录。文件名建议：`YYYYMMDD-简短描述.md`。\n\n'
          '## 模板\n\n'
          '```markdown\n'
          '---\n'
          '症状：问题表现/报错信息\n'
          '关键词：grep 用关键词，逗号分隔\n'
          '时间：YYYY-MM-DD\n'
          '结果：已解决 / 临时绕过 / 待观察\n'
          '来源：手动排查 / AI 辅助 / 同事提供\n'
          'source: private  # 或 opensource\n'
          '---\n\n'
          '## 根因\n'
          '<问题的根本原因>\n\n'
          '## 解法\n'
          '<具体步骤，可含代码片段>\n\n'
          '## 关联\n'
          '<相关的 playbook、文件、issue 等>\n'
          '```\n\n'
          '写完后在 `MEMORY.md` 加一行指针。\n';

      // 4. playbooks/ 程序记忆模板
      final playbooks = '# playbooks/ — 套路模板\n\n'
          '本目录存放从多次 solved 提炼出的套路。文件名建议：`动作-对象.md`（如 `排查-启动卡顿.md`）。\n\n'
          '## 模板\n\n'
          '```markdown\n'
          '# <套路名称>\n\n'
          '## 何时用\n'
          '<触发条件/症状特征>\n\n'
          '## 步骤\n'
          '1. <第一步>\n'
          '2. <第二步>\n'
          '3. <第N步>\n\n'
          '## 来自\n'
          '- <solved 记录1>\n'
          '- <solved 记录2>\n'
          '```\n\n'
          '当某类问题在 `solved/` 出现 ≥2 次，提炼一条 playbook。\n';

      out.add(FileArtifact(
          'memory/${s.name}/MEMORY.md', index, isMemory: true));
      out.add(FileArtifact(
          'memory/${s.name}/solved/README.md', solved, isMemory: true));
      out.add(FileArtifact(
          'memory/${s.name}/playbooks/README.md', playbooks, isMemory: true));
    }
    return out;
  }
}
