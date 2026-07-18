// crew_gui/lib/ui/new_project_page.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/project_entry.dart';
import '../services/directory_picker.dart';
import '../services/project_store.dart';
import '../services/template_repository.dart';
import '../services/workspace_opener.dart';
import '../state/generation_controller.dart';
import '../state/wizard_controller.dart';
import 'wizard/step_done.dart';

/// 填充式新建项目页面：所有字段在同一个表单中，必填项标 *，
/// 缺少必填条件时底部「生成」按钮禁用并显示缺失项。
class NewProjectPage extends StatefulWidget {
  final WizardController wizard;
  final TemplateRepository templates;
  final DirectoryPicker picker;
  final GenerationController generation;
  final WorkspaceOpener opener;
  final ProjectStore store;
  final VoidCallback onDone;
  const NewProjectPage({
    super.key,
    required this.wizard,
    required this.templates,
    required this.picker,
    required this.generation,
    required this.opener,
    required this.store,
    required this.onDone,
  });

  @override
  State<NewProjectPage> createState() => _NewProjectPageState();
}

class _NewProjectPageState extends State<NewProjectPage> {
  final _scrollController = ScrollController();
  bool _emitted = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _workspaceRoot() =>
      p.join(widget.wizard.workspaceParent, widget.wizard.projectName);

  String _today() {
    final n = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  /// 必填项校验：返回缺失项列表（空列表 = 全部满足）。
  List<String> _missingRequired() {
    final w = widget.wizard;
    final out = <String>[];
    if (w.projectName.isEmpty) out.add('项目名');
    if (w.workspaceParent.isEmpty) out.add('生成位置');
    if (w.directories.isEmpty) out.add('代码目录');
    if (w.selectedTemplates.isEmpty) out.add('专家');
    return out;
  }

  bool get _canGenerate => _missingRequired().isEmpty;

  Future<void> _onGenerateOrConfirm() async {
    final w = widget.wizard;
    final g = widget.generation;
    if (g.plan == null) {
      // 阶段 1：生成预览（plan）
      await g.generateAndPlan(
        _workspaceRoot(),
        w.buildConfig(createdAt: _today()),
      );
      if (g.plan != null && mounted) {
        // 滚到底部让用户看到 plan 与确认按钮
        await Future.delayed(const Duration(milliseconds: 50));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
      return;
    }
    // 阶段 2：确认写入磁盘
    await g.confirmAndEmit(_workspaceRoot());
    if (g.status == GenStatus.done) {
      await widget.store.add(ProjectEntry(
        name: w.projectName,
        path: _workspaceRoot(),
        createdAt: _today(),
        repoCount: w.directories.length,
        agentCount: w.selectedTemplates.length,
      ));
      if (mounted) setState(() => _emitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_emitted && widget.generation.status == GenStatus.done) {
      return _buildDoneView();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('新建 Crew 项目')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge(
                      [widget.wizard, widget.generation]),
                  builder: (context, _) {
                    return ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        _Section(
                          label: '项目信息',
                          required: true,
                          child: _ProjectInfoFields(
                            wizard: widget.wizard,
                            picker: widget.picker,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _Section(
                          label: '代码目录',
                          required: true,
                          child: _DirectoriesFields(
                            wizard: widget.wizard,
                            picker: widget.picker,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _Section(
                          label: '专家',
                          required: true,
                          child: _AgentsFields(
                            wizard: widget.wizard,
                            templates: widget.templates.all,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _Section(
                          label: '关联专家到目录',
                          required: false,
                          hint: '可选 — 可跳过由 AI 自动分配',
                          child: _AssignFields(wizard: widget.wizard),
                        ),
                        const SizedBox(height: 20),
                        _Section(
                          label: '生成目标',
                          required: false,
                          hint: '默认生成 Claude + Codex 配置',
                          child: _TargetsFields(wizard: widget.wizard),
                        ),
                        const SizedBox(height: 20),
                        _GenerationStatus(generation: widget.generation),
                      ],
                    );
                  },
                ),
              ),
              ListenableBuilder(
                listenable: Listenable.merge(
                    [widget.wizard, widget.generation]),
                builder: (context, _) => _buildBottomBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final missing = _missingRequired();
    final g = widget.generation;
    final hasPlan = g.plan != null;
    final isBusy =
        g.status == GenStatus.generating || g.status == GenStatus.emitting;
    final canConfirm = hasPlan && g.status == GenStatus.planned;
    final buttonLabel = hasPlan ? '确认生成' : '生成预览';
    final buttonEnabled = _canGenerate && !isBusy && !_emitted;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Row(
            children: [
              Expanded(
                child: missing.isEmpty
                    ? (canConfirm
                        ? Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '已可生成 — 将写入 ${g.plan!.writes.length} 个文件',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            isBusy ? '生成中…' : '必填项已就绪，点击右侧按钮开始生成',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ))
                    : Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 14, color: theme.colorScheme.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '缺少必填项：${missing.join('、')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: isBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(hasPlan ? Icons.check_rounded : Icons.preview,
                        size: 18),
                label: Text(buttonLabel),
                onPressed: buttonEnabled ? _onGenerateOrConfirm : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoneView() {
    return StepDone(
      workspacePath: _workspaceRoot(),
      opener: widget.opener,
      cliTool: widget.wizard.cliTool,
      onFinish: widget.onDone,
    );
  }
}

// ─── 通用区块组件 ─────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final bool required;
  final String? hint;
  final Widget child;
  const _Section({
    required this.label,
    required this.required,
    required this.child,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFFF5C5C),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
            if (hint != null) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  hint!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// ─── 项目信息（项目名 + 生成位置） ───────────────────────

class _ProjectInfoFields extends StatelessWidget {
  final WizardController wizard;
  final DirectoryPicker picker;
  const _ProjectInfoFields({required this.wizard, required this.picker});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: '项目名 *',
            hintText: '生成的目录名，如 apm',
          ),
          onChanged: wizard.setProjectName,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  wizard.workspaceParent.isEmpty
                      ? '未选择生成位置 *'
                      : '生成到：${p.join(wizard.workspaceParent, wizard.projectName.isEmpty ? '<项目名>' : wizard.projectName)}',
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  final dir = await picker.pick();
                  if (dir != null) wizard.setWorkspaceParent(dir);
                },
                child: const Text('选择位置'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 代码目录 ─────────────────────────────────────────────

class _DirectoriesFields extends StatelessWidget {
  final WizardController wizard;
  final DirectoryPicker picker;
  const _DirectoriesFields({required this.wizard, required this.picker});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: wizard,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wizard.directories.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.folder_off_outlined,
                        size: 24, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 6),
                    Text(
                      '尚未添加目录 *',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: wizard.directories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final d = wizard.directories[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    child: Row(
                      children: [
                        Icon(Icons.folder_outlined,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            d,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          tooltip: '移除',
                          onPressed: () => wizard.removeDirectory(d),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('添加目录'),
              onPressed: () async {
                final path = await picker.pick();
                if (path != null) wizard.addDirectory(path);
              },
            ),
          ],
        );
      },
    );
  }
}

// ─── 专家 ─────────────────────────────────────────────────

class _AgentsFields extends StatelessWidget {
  final WizardController wizard;
  final List<AgentTemplate> templates;
  const _AgentsFields({required this.wizard, required this.templates});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (templates.isEmpty) {
      return Text('暂无可用专家模板',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    return ListenableBuilder(
      listenable: wizard,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 智能识别按钮 + 说明
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('智能识别'),
                  onPressed: wizard.directories.isEmpty
                      ? null
                      : () => wizard.autoDetect(templates),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    wizard.directories.isEmpty
                        ? '先添加代码目录，再点智能识别'
                        : wizard.lastScan.isEmpty
                            ? '点击扫描目录，自动选专家+关联'
                            : '已识别 ${wizard.lastScan.length} 条匹配',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: templates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final t = templates[i];
                final selected = wizard.isSelected(t);
                final signals = wizard.signalsFor(t);
                return Material(
                  color: selected
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => wizard.toggleTemplate(t),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary.withValues(alpha: 0.6)
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: selected,
                              onChanged: (_) => wizard.toggleTemplate(t),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t.role,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t.displayName} · ${t.ref}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (signals.isNotEmpty)
                            Tooltip(
                              message: signals.join('\n'),
                              waitDuration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer
                                      .withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt,
                                        size: 11,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${signals.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ─── 关联专家到目录 ───────────────────────────────────────

const _ignoreSubdirs = {
  'node_modules', 'build', 'dist', 'target', '__pycache__',
  'Pods', 'DerivedData', '.git', '.gradle', '.idea', '.vscode',
  '.dart_tool', 'ephemeral',
};

class _AssignFields extends StatelessWidget {
  final WizardController wizard;
  const _AssignFields({required this.wizard});

  List<String> _selectableDirs() {
    final result = <String>[];
    for (final root in wizard.directories) {
      result.add(root);
      final dir = Directory(root);
      if (dir.existsSync()) {
        for (final entry in dir.listSync(followLinks: false)) {
          if (entry is Directory) {
            final name = p.basename(entry.path);
            if (!name.startsWith('.') && !_ignoreSubdirs.contains(name)) {
              result.add(entry.path);
            }
          }
        }
      }
    }
    return result;
  }

  String _shortLabel(String dir) {
    if (wizard.directories.contains(dir)) return p.basename(dir);
    final parent = p.dirname(dir);
    return '${p.basename(parent)}/${p.basename(dir)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: wizard,
      builder: (context, _) {
        final nonPm =
            wizard.selectedTemplates.where((t) => t.id != 'pm').toList();
        if (nonPm.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              '请先选择专家（产品经理角色无需关联）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final selectable = _selectableDirs();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('自动分配'),
                  onPressed: wizard.autoAssign,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: const Text('跳过'),
                  onPressed: wizard.skipAssign,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final t in nonPm)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AgentAssignCard(
                  template: t,
                  selectable: selectable,
                  shortLabel: _shortLabel,
                  assignments:
                      wizard.assignments[wizard.agentNameFor(t)] ?? const [],
                  onToggleDir: (dir, sel) {
                    final name = wizard.agentNameFor(t);
                    final cur = <String>[
                      ...(wizard.assignments[name] ?? const [])
                    ];
                    sel ? cur.add(dir) : cur.remove(dir);
                    wizard.setAssignment(name, cur);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AgentAssignCard extends StatelessWidget {
  final AgentTemplate template;
  final List<String> selectable;
  final String Function(String) shortLabel;
  final List<String> assignments;
  final void Function(String dir, bool sel) onToggleDir;
  const _AgentAssignCard({
    required this.template,
    required this.selectable,
    required this.shortLabel,
    required this.assignments,
    required this.onToggleDir,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = template.displayName.isNotEmpty
        ? template.displayName.characters.first
        : '?';
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${template.displayName}（${template.role}）',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '已选 ${assignments.length} / ${selectable.length} 个目录',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final dir in selectable)
                FilterChip(
                  label: Text(shortLabel(dir)),
                  selected: assignments.contains(dir),
                  onSelected: (sel) => onToggleDir(dir, sel),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: assignments.contains(dir)
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 生成目标 + CLI 工具 ──────────────────────────────────

class _TargetsFields extends StatelessWidget {
  final WizardController wizard;
  const _TargetsFields({required this.wizard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: wizard,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Claude Code（.claude/agents/*.md）'),
                    value: wizard.targets.contains('claude'),
                    onChanged: (_) => wizard.toggleTarget('claude'),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  ),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  SwitchListTile(
                    title: const Text('Codex（.codex/agents/*.toml）'),
                    value: wizard.targets.contains('codex'),
                    onChanged: (_) => wizard.toggleTarget('codex'),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'CLI 探查工具',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<String>(
                    title: const Text('claude'),
                    value: 'claude',
                    groupValue: wizard.cliTool,
                    onChanged: (v) => wizard.setCliTool(v!),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  ),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  RadioListTile<String>(
                    title: const Text('codex'),
                    value: 'codex',
                    groupValue: wizard.cliTool,
                    onChanged: (v) => wizard.setCliTool(v!),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── 生成状态（进度 / 错误 / plan 列表） ──────────────────

class _GenerationStatus extends StatelessWidget {
  final GenerationController generation;
  const _GenerationStatus({required this.generation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: generation,
      builder: (context, _) {
        if (generation.status == GenStatus.generating ||
            generation.status == GenStatus.emitting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(
                generation.status == GenStatus.emitting ? '正在写入文件…' : '正在生成预览…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }
        if (generation.status == GenStatus.error && generation.error != null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: 14, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '生成失败：${generation.error}',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          );
        }
        if (generation.plan != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.preview_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '将写入 ${generation.plan!.writes.length} 个文件',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: theme.colorScheme.outlineVariant),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final w in generation.plan!.writes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                w.targetPath,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                w.action.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
