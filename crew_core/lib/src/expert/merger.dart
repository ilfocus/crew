// crew_core/lib/src/expert/merger.dart
import '../models/expert.dart';
import '../runner/runner.dart';
import '../runner/distill_parser.dart';

/// 把一个 [project] Expert（L1）蒸馏并合并进 [domain] Expert（L2）。
///
/// 流程：
/// 1. 用 project 的 L1 memory（solved + playbooks + notes）构造 distill prompt
/// 2. 调用 [runner.distill] 拿到 L2 抽象
/// 3. 用 [parseDistill] 解析为 [DistillResult]
/// 4. 把结果合并进 domain：
///    - notes 追加 distillResult.domainNotes
///    - playbooks 按 path 去重后追加
///    - projects 按 id 去重后追加 ProjectRef(projectId, summary)
///    - learnedProjectIds 按 id 去重后追加 projectId
///
/// 幂等性：即使 projectId 已在 learnedProjectIds 中，仍会执行 distill
/// （可能产出新的 playbooks），但 projects/learnedProjectIds 不会重复增长。
Future<Expert> mergeIntoDomain({
  required Expert domain,
  required Expert project,
  required Runner runner,
  required int version,
}) async {
  final prompt = _buildDistillPrompt(project);
  final result = await runner.distill(prompt: prompt);
  final distill = parseDistill(result.rawOutput);

  final projectId = project.meta.projectId;
  final projectSummary = _projectSummary(project);

  // --- 合并 notes（追加，不做去重；distill 输出本身应当是抽象的） ---
  final mergedNotes = domain.memory.notes.isEmpty
      ? distill.domainNotes
      : (distill.domainNotes.isEmpty
          ? domain.memory.notes
          : '${domain.memory.notes}\n\n---\n\n${distill.domainNotes}');

  // --- 合并 playbooks（按 path 去重，新的覆盖旧的语义但保留首次出现位置） ---
  // 策略：保留 domain 已有 + 追加 distill 中 path 不存在的项
  final existingPaths = <String>{};
  final mergedPlaybooks = <MemoryEntry>[];
  for (final pb in domain.memory.playbooks) {
    if (existingPaths.add(pb.path)) {
      mergedPlaybooks.add(pb);
    }
  }
  for (final pb in distill.playbooks) {
    if (existingPaths.add(pb.path)) {
      mergedPlaybooks.add(pb);
    }
  }

  // --- 合并 projects（按 id 去重） ---
  final existingProjectIds = <String>{};
  final mergedProjects = <ProjectRef>[];
  for (final p in domain.memory.projects) {
    if (existingProjectIds.add(p.id)) {
      mergedProjects.add(p);
    }
  }
  if (projectId.isNotEmpty && !existingProjectIds.contains(projectId)) {
    mergedProjects.add(ProjectRef(projectId, projectSummary));
    existingProjectIds.add(projectId);
  }

  // --- 合并 learnedProjectIds（按 id 去重） ---
  final mergedLearned = <String>[...domain.meta.learnedProjectIds];
  if (projectId.isNotEmpty && !mergedLearned.contains(projectId)) {
    mergedLearned.add(projectId);
  }

  return Expert(
    kind: ExpertKind.domain,
    domain: domain.domain,
    spec: domain.spec,
    memory: ExpertMemory(
      index: domain.memory.index,
      notes: mergedNotes,
      solved: domain.memory.solved,
      playbooks: mergedPlaybooks,
      projects: mergedProjects,
    ),
    meta: ExpertMeta(
      source: domain.meta.source,
      github: domain.meta.github,
      retention: domain.meta.retention,
      projectId: domain.meta.projectId,
      version: version,
      learnedProjectIds: mergedLearned,
    ),
  );
}

String _buildDistillPrompt(Expert project) {
  final sb = StringBuffer()
    ..writeln('请把下面这个项目专家的 L1 记忆抽象为领域级（L2）笔记与 playbooks。')
    ..writeln('输出 JSON：{"domainNotes": String, "playbooks": [{"path": String, "content": String}]}')
    ..writeln()
    ..writeln('## 项目角色')
    ..writeln(project.spec.role.isNotEmpty ? project.spec.role : '(未填写)')
    ..writeln()
    ..writeln('## 技术栈')
    ..writeln(project.spec.techStack.isEmpty
        ? '(未填写)'
        : project.spec.techStack.join(', '))
    ..writeln()
    ..writeln('## 重难点')
    ..writeln(project.spec.difficulties.isEmpty
        ? '(未填写)'
        : project.spec.difficulties.join('\n- '))
    ..writeln();

  sb
    ..writeln('## L1 notes')
    ..writeln(project.memory.notes.isEmpty ? '(空)' : project.memory.notes)
    ..writeln();

  sb..writeln('## solved entries')..writeln();
  if (project.memory.solved.isEmpty) {
    sb.writeln('(空)');
  } else {
    for (final s in project.memory.solved) {
      sb.writeln('- path: ${s.path}');
      sb.writeln('  content: ${s.content}');
    }
  }
  sb.writeln();

  sb..writeln('## existing playbooks')..writeln();
  if (project.memory.playbooks.isEmpty) {
    sb.writeln('(空)');
  } else {
    for (final p in project.memory.playbooks) {
      sb.writeln('- path: ${p.path}');
      sb.writeln('  content: ${p.content}');
    }
  }

  return sb.toString();
}

String _projectSummary(Expert project) {
  if (project.spec.role.isNotEmpty) return project.spec.role;
  if (project.spec.displayName.isNotEmpty) return project.spec.displayName;
  return project.meta.projectId;
}
