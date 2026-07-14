// crew_gui/lib/ui/wizard/step_directories.dart
import 'package:flutter/material.dart';
import '../../services/directory_picker.dart';
import '../../state/wizard_controller.dart';

class StepDirectories extends StatelessWidget {
  final WizardController wizard;
  final DirectoryPicker picker;
  const StepDirectories({super.key, required this.wizard, required this.picker});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wizard,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择这个项目关联的一个或多个代码目录：'),
          const SizedBox(height: 8),
          for (final d in wizard.directories)
            ListTile(
              dense: true,
              leading: const Icon(Icons.folder_outlined),
              title: Text(d),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => wizard.removeDirectory(d),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('添加目录'),
            onPressed: () async {
              final path = await picker.pick();
              if (path != null) wizard.addDirectory(path);
            },
          ),
        ],
      ),
    );
  }
}
