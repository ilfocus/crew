// crew_gui/lib/ui/wizard/step_targets.dart
import 'package:flutter/material.dart';
import '../../state/wizard_controller.dart';

class StepTargets extends StatelessWidget {
  final WizardController wizard;
  const StepTargets({super.key, required this.wizard});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wizard,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('生成哪些工具的配置：'),
          SwitchListTile(
            title: const Text('Claude Code（.claude/agents/*.md）'),
            value: wizard.targets.contains('claude'),
            onChanged: (_) => wizard.toggleTarget('claude'),
          ),
          SwitchListTile(
            title: const Text('Codex（.codex/agents/*.toml）'),
            value: wizard.targets.contains('codex'),
            onChanged: (_) => wizard.toggleTarget('codex'),
          ),
          const Divider(),
          const Text('生成时用哪个 CLI 探查代码：'),
          RadioListTile<String>(
            title: const Text('claude'),
            value: 'claude',
            groupValue: wizard.cliTool,
            onChanged: (v) => wizard.setCliTool(v!),
          ),
          RadioListTile<String>(
            title: const Text('codex'),
            value: 'codex',
            groupValue: wizard.cliTool,
            onChanged: (v) => wizard.setCliTool(v!),
          ),
        ],
      ),
    );
  }
}
