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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已生成到：$workspacePath'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.terminal),
              label: Text('用 $cliTool 打开'),
              onPressed: () => opener.openWithTool(cliTool, workspacePath),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('打开文件夹'),
              onPressed: () => opener.openFolder(workspacePath),
            ),
            TextButton(onPressed: onFinish, child: const Text('完成')),
          ],
        ),
      ],
    );
  }
}
