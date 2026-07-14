// crew_gui/lib/ui/wizard/step_preview.dart
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../services/directory_picker.dart';
import '../../state/generation_controller.dart';
import '../../state/wizard_controller.dart';

class StepPreview extends StatelessWidget {
  final WizardController wizard;
  final GenerationController generation;
  final DirectoryPicker picker;
  const StepPreview({
    super.key,
    required this.wizard,
    required this.generation,
    required this.picker,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([wizard, generation]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: const InputDecoration(labelText: '项目名（生成的目录名）'),
            onChanged: wizard.setProjectName,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(wizard.workspaceParent.isEmpty
                    ? '未选择生成位置'
                    : '生成到：${p.join(wizard.workspaceParent, wizard.projectName)}'),
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
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.preview),
            label: const Text('生成预览'),
            onPressed: wizard.canProceedPreview()
                ? () => generation.generateAndPlan(
                      p.join(wizard.workspaceParent, wizard.projectName),
                      wizard.buildConfig(createdAt: _today()),
                    )
                : null,
          ),
          const SizedBox(height: 8),
          if (generation.status == GenStatus.generating)
            const LinearProgressIndicator(),
          if (generation.status == GenStatus.error)
            Text('生成失败：${generation.error}',
                style: const TextStyle(color: Colors.red)),
          if (generation.plan != null) ...[
            const Text('将写入的文件：'),
            for (final w in generation.plan!.writes)
              Text('· ${w.targetPath}  [${w.action.name}]'),
          ],
        ],
      ),
    );
  }

  String _today() {
    final n = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }
}

extension on WizardController {
  bool canProceedPreview() =>
      projectName.isNotEmpty && workspaceParent.isNotEmpty;
}
