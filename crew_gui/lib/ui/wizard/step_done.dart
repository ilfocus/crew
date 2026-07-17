// crew_gui/lib/ui/wizard/step_done.dart
import 'package:flutter/material.dart';
import '../../services/workspace_opener.dart';

class StepDone extends StatelessWidget {
  final String workspacePath;
  final WorkspaceOpener opener;
  final String cliTool;
  final VoidCallback onFinish;
  const StepDone({
    super.key,
    required this.workspacePath,
    required this.opener,
    required this.cliTool,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.check_rounded,
                        color: theme.colorScheme.onPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '生成完成',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '已生成到：$workspacePath',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.terminal, size: 18),
                  label: Text('用 $cliTool 打开'),
                  onPressed: () => opener.openWithTool(cliTool, workspacePath),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('打开文件夹'),
                  onPressed: () => opener.openFolder(workspacePath),
                ),
                TextButton(onPressed: onFinish, child: const Text('完成')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
