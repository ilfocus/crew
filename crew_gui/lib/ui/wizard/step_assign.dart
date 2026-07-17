// crew_gui/lib/ui/wizard/step_assign.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../state/wizard_controller.dart';

const _ignoreSubdirs = {
  'node_modules', 'build', 'dist', 'target', '__pycache__',
  'Pods', 'DerivedData', '.git', '.gradle', '.idea', '.vscode',
  '.dart_tool', 'ephemeral',
};

class StepAssign extends StatelessWidget {
  final WizardController wizard;
  const StepAssign({super.key, required this.wizard});

  /// 收集所有可选目录：顶层目录 + 其直接子目录（过滤隐藏/构建目录）
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
    // 顶层目录显示 basename，子目录显示 parent/basename
    if (wizard.directories.contains(dir)) {
      return p.basename(dir);
    }
    final parent = p.dirname(dir);
    return '${p.basename(parent)}/${p.basename(dir)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListenableBuilder(
          listenable: wizard,
          builder: (context, _) {
            final nonPm = wizard.selectedTemplates
                .where((t) => t.id != 'pm')
                .toList();
            final selectable = _selectableDirs();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        wizard.assignSkipped
                            ? '已跳过 — AI 将在生成时自动分析并分配'
                            : '把每个专家关联到对应目录（可跳过，由 AI 自动分配）：',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                if (selectable.length > wizard.directories.length) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '提示：已展开子目录，可按需选择更细粒度的工作范围',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                for (final t in nonPm)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
        ),
      ),
    );
  }
}

class _AgentAssignCard extends StatelessWidget {
  final dynamic template; // AgentTemplate
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
    final initial = (template.displayName as String).isNotEmpty
        ? (template.displayName as String).characters.first
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
