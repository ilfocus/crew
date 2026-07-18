// crew_core/lib/src/expert/merger.dart
import '../models/domain_expertise.dart';
import '../models/expert.dart' show MemoryEntry, ProjectRef;
import '../models/project_competence.dart';
import '../runner/distill_parser.dart';
import '../runner/runner.dart';

/// 蒸馏并合并结果：返回更新后的 [domain] 与反向索引已更新的 [project]。
class MergeOutcome {
  final DomainExpertise domain;
  final ProjectCompetence project;
  const MergeOutcome(this.domain, this.project);
}

/// 把某 agent 的一个 [ProjectCompetence]（L1）蒸馏并并入其某个 [DomainExpertise]（L2）。
///
/// 流程：
/// 1. 用 project 的 L1 memory（notes + solved + playbooks）构造 distill prompt
/// 2. 调用 [runner.distill] 拿到 L2 抽象（[DistillResult]）
/// 3. 合并进 domain：
///    - notes 追加 distill.domainNotes（空则保留原）
///    - playbooks 按 path 去重后追加（已存在不覆盖）
///    - projects 按 id 去重追加 [ProjectRef]（幂等）
/// 4. 同步把 domain 名加入 project.domains（反向索引，去重）
///
/// **多对多**：一个 project 可被并入多个 domain → 各 domain 的 `projects` 都含它，
/// `project.domains` 反向含所有并入过的 domain。
///
/// 幂等性：即便 projectId 已在 domain.projects 中，仍会执行 distill（可能产出
/// 新 playbooks），但 projects/domains 不会重复增长。
Future<MergeOutcome> mergeIntoDomain({
  required DomainExpertise domain,
  required ProjectCompetence project,
  required Runner runner,
}) async {
  final prompt = _buildDistillPrompt(project);
  final result = await runner.distill(prompt: prompt);
  final distill = parseDistill(result.rawOutput);

  // --- notes 追加（distill 输出本身已抽象） ---
  final mergedNotes = domain.notes.isEmpty
      ? distill.domainNotes
      : (distill.domainNotes.isEmpty
          ? domain.notes
          : '${domain.notes}\n\n---\n\n${distill.domainNotes}');

  // --- playbooks 按 path 去重（已存在不覆盖） ---
  final existingPaths = <String>{};
  final mergedPlaybooks = <MemoryEntry>[];
  for (final pb in domain.playbooks) {
    if (existingPaths.add(pb.path)) {
      mergedPlaybooks.add(pb);
    }
  }
  for (final pb in distill.playbooks) {
    if (existingPaths.add(pb.path)) {
      mergedPlaybooks.add(pb);
    }
  }

  // --- projects 按 id 去重追加 ---
  final existingProjectIds = <String>{};
  final mergedProjects = <ProjectRef>[];
  for (final p in domain.projects) {
    if (existingProjectIds.add(p.id)) {
      mergedProjects.add(p);
    }
  }
  final projectId = project.projectId;
  if (projectId.isNotEmpty && !existingProjectIds.contains(projectId)) {
    mergedProjects.add(ProjectRef(projectId, _projectSummary(project)));
  }

  // --- project.domains 反向索引（去重追加） ---
  final updatedDomains = <String>[...project.domains];
  if (domain.domain.isNotEmpty && !updatedDomains.contains(domain.domain)) {
    updatedDomains.add(domain.domain);
  }

  final updatedDomain = DomainExpertise(
    domain: domain.domain,
    notes: mergedNotes,
    principles: domain.principles,
    playbooks: mergedPlaybooks,
    projects: mergedProjects,
  );
  final updatedProject = ProjectCompetence(
    projectId: project.projectId,
    repos: project.repos,
    coordinates: project.coordinates,
    moduleStructure: project.moduleStructure,
    keyFiles: project.keyFiles,
    dataflow: project.dataflow,
    techStack: project.techStack,
    sdks: project.sdks,
    difficulties: project.difficulties,
    github: project.github,
    source: project.source,
    retention: project.retention,
    notes: project.notes,
    solved: project.solved,
    playbooks: project.playbooks,
    domains: updatedDomains,
  );
  return MergeOutcome(updatedDomain, updatedProject);
}

String _buildDistillPrompt(ProjectCompetence project) {
  final sb = StringBuffer()
    ..writeln('请把下面这个项目的 L1 记忆抽象为领域级（L2）笔记与 playbooks。')
    ..writeln('输出 JSON：{"domainNotes": String, "playbooks": [{"path": String, "content": String}]}')
    ..writeln()
    ..writeln('## 项目坐标')
    ..writeln(project.coordinates.isEmpty ? '(未填写)' : project.coordinates)
    ..writeln()
    ..writeln('## 模块结构')
    ..writeln(project.moduleStructure.isEmpty
        ? '(未填写)'
        : project.moduleStructure)
    ..writeln()
    ..writeln('## 技术栈')
    ..writeln(
        project.techStack.isEmpty ? '(未填写)' : project.techStack.join(', '))
    ..writeln()
    ..writeln('## 重难点')
    ..writeln(project.difficulties.isEmpty
        ? '(未填写)'
        : project.difficulties.join('\n- '))
    ..writeln();

  sb
    ..writeln('## L1 notes')
    ..writeln(project.notes.isEmpty ? '(空)' : project.notes)
    ..writeln();

  sb..writeln('## solved entries')..writeln();
  if (project.solved.isEmpty) {
    sb.writeln('(空)');
  } else {
    for (final s in project.solved) {
      sb.writeln('- path: ${s.path}');
      sb.writeln('  content: ${s.content}');
    }
  }
  sb.writeln();

  sb..writeln('## existing playbooks')..writeln();
  if (project.playbooks.isEmpty) {
    sb.writeln('(空)');
  } else {
    for (final p in project.playbooks) {
      sb.writeln('- path: ${p.path}');
      sb.writeln('  content: ${p.content}');
    }
  }

  return sb.toString();
}

String _projectSummary(ProjectCompetence project) {
  // ProjectCompetence 没有独立的 role/displayName 字段——回退到 projectId。
  return project.projectId;
}
