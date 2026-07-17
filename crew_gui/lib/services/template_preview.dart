// crew_gui/lib/services/template_preview.dart
import 'package:crew_core/crew_core.dart';

/// 根据专家模板渲染其生成后会产出的 md 文件预览。
///
/// 由于模板本身没有探查得到的 spec 字段（coordinates/moduleStructure/techStack 等），
/// 预览时这些字段留空，只渲染模板带有的 personality/principles/role/displayName。
class TemplatePreview {
  const TemplatePreview();

  /// 由模板构造一个 AgentSpec（探查相关字段留空）。
  AgentSpec specFromTemplate(AgentTemplate t) => AgentSpec(
        name: t.defaultName,
        displayName: t.displayName,
        repos: const [],
        role: t.role,
        coordinates: '',
        moduleStructure: '',
        keyFiles: const [],
        dataflow: '',
        memoryConvention: '',
        conventions: const [],
        personality: t.personality,
        principles: t.principles,
      );

  /// 渲染 `.claude/agents/<name>.md` 的内容（含 YAML frontmatter）。
  String renderClaudeAgent(AgentTemplate t) {
    final spec = specFromTemplate(t);
    final body = renderAgentBody(spec);
    final buf = StringBuffer()
      ..writeln('---')
      ..writeln('name: ${spec.name}')
      ..writeln('description: ${spec.role}')
      ..writeln('---')
      ..writeln()
      ..write(body);
    return buf.toString();
  }

  /// 渲染 `.codex/agents/<name>.toml` 的内容。
  String renderCodexAgent(AgentTemplate t) {
    final spec = specFromTemplate(t);
    final body = renderAgentBody(spec);
    final buf = StringBuffer()
      ..writeln('name = "${spec.name}"')
      ..writeln('description = "${spec.role}"')
      ..writeln()
      ..writeln('developer_instructions = """')
      ..write(body)
      ..writeln('"""');
    return buf.toString();
  }

  /// 渲染 `memory/<name>/MEMORY.md` 的内容。
  String renderMemoryIndex(AgentTemplate t) {
    final spec = specFromTemplate(t);
    final buf = StringBuffer()
      ..writeln('# ${spec.displayName} 记忆索引')
      ..writeln()
      ..writeln('> 开工先读本文件，了解记忆结构与当前指针。')
      ..writeln()
      ..writeln('## 记忆结构')
      ..writeln()
      ..writeln('- `project-notes.md` — 语义记忆：技术栈、SDK、重难点、关键文件')
      ..writeln('- `solved/` — 情景记忆：每个已解决问题一条记录')
      ..writeln('- `playbooks/` — 程序记忆：从 solved 提炼的套路')
      ..writeln()
      ..writeln('## 成长约定')
      ..writeln()
      ..writeln('### 开工召回')
      ..writeln('1. 读本文件了解记忆结构。')
      ..writeln('2. 遇到问题时 grep `solved/` 找相似问题的解决记录。')
      ..writeln('3. 再 grep `playbooks/` 看是否有现成套路。')
      ..writeln('4. 命中即复用；未命中再动手排查。')
      ..writeln()
      ..writeln('### 收工蒸馏')
      ..writeln('1. 新问题解决后写一条记录到 `solved/`。')
      ..writeln('2. 新事实更新 `project-notes.md`。')
      ..writeln('3. 某类问题出现 ≥2 次，提炼一条 playbook。')
      ..writeln('4. 更新本文件索引指针。');
    return buf.toString();
  }

  /// 渲染 `memory/<name>/project-notes.md` 的内容。
  String renderProjectNotes(AgentTemplate t) {
    final spec = specFromTemplate(t);
    final buf = StringBuffer()
      ..writeln('# ${spec.displayName} · 项目笔记')
      ..writeln()
      ..writeln('## 角色')
      ..writeln(spec.role.isEmpty ? '_(未指定)_' : spec.role)
      ..writeln();
    if (spec.personality.isNotEmpty) {
      buf
        ..writeln('## 人格')
        ..writeln(spec.personality)
        ..writeln();
    }
    if (spec.principles.isNotEmpty) {
      buf
        ..writeln('## 判断标准')
        ..writeln('- ${spec.principles.join('\n- ')}')
        ..writeln();
    }
    buf
      ..writeln('## 技术栈')
      ..writeln('_(探查后填充)_')
      ..writeln()
      ..writeln('## 重难点')
      ..writeln('_(探查后填充)_');
    return buf.toString();
  }
}
