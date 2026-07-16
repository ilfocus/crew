import '../models/file_artifact.dart';
import '../models/generation_result.dart';
import 'output_adapter.dart';

class DocsAdapter implements OutputAdapter {
  @override
  String get target => 'docs';

  @override
  List<FileArtifact> render(GenerationResult result) {
    final team = result.team;
    final roster = StringBuffer();
    for (final m in team.members) {
      roster.writeln('- **${m.displayName}**（${m.role}）— ${m.repos.join('、')}');
    }
    final body = '# ${team.name} 团队\n\n'
        '本工作空间由 Crew 生成。团队成员：\n\n'
        '$roster\n'
        '## 协作约定\n'
        '- 由产品经理(PM)统筹需求，按目录派给对应专家。\n'
        '- 每个专家开工前读 `memory/<name>/MEMORY.md`，收工后写回记忆。\n\n'
        '## 团队记忆与成长约定\n'
        '- **开工召回**：每个专家开工时先读自己的 `memory/<name>/MEMORY.md`，'
        '用症状关键词 grep `solved/` 和 `playbooks/`，命中即复用。\n'
        '- **收工蒸馏**：每次解决问题后写 `solved/` 记录；同类问题 ≥2 次提炼 `playbooks/`；'
        '更新 `MEMORY.md` 索引；过时记忆及时修正。\n'
        '- 团队成员共享 `project-notes.md` 中的技术栈与架构信息，保持认知同步。\n';

    final onboarding = '# 上手说明（${team.name}）\n\n'
        '用 Claude Code 或 Codex 打开本目录，先跟"产品(PM)"对话说明你的目标，'
        '由 PM 协调各专家推进。成员见 AGENTS.md。\n';

    return [
      FileArtifact('CLAUDE.md', body),
      FileArtifact('AGENTS.md', body),
      FileArtifact('ONBOARDING.md', onboarding),
    ];
  }
}
