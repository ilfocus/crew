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
    return ListenableBuilder(
      listenable: wizard,
      builder: (context, _) {
        final nonPm =
            wizard.selectedTemplates.where((t) => t.id != 'pm').toList();
        final selectable = _selectableDirs();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(wizard.assignSkipped
                      ? '已跳过 — AI 将在生成时自动分析并分配'
                      : '把每个专家关联到对应目录（可跳过，由 AI 自动分配）：'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('自动分配'),
                  onPressed: wizard.autoAssign,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.skip_next),
                  label: const Text('跳过'),
                  onPressed: wizard.skipAssign,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (selectable.length > wizard.directories.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '提示：已展开子目录，可按需选择更细粒度的工作范围',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            for (final t in nonPm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t.displayName}（${t.role}）'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final dir in selectable)
                          FilterChip(
                            label: Text(_shortLabel(dir)),
                            selected: (wizard
                                        .assignments[wizard.agentNameFor(t)] ??
                                    const [])
                                .contains(dir),
                            onSelected: (sel) {
                              final name = wizard.agentNameFor(t);
                              final cur = <String>[
                                ...(wizard.assignments[name] ?? const [])
                              ];
                              sel ? cur.add(dir) : cur.remove(dir);
                              wizard.setAssignment(name, cur);
                            },
                          ),
                      ],
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
