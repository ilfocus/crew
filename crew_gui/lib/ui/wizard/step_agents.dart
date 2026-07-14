// crew_gui/lib/ui/wizard/step_agents.dart
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import '../../state/wizard_controller.dart';

class StepAgents extends StatelessWidget {
  final WizardController wizard;
  final List<AgentTemplate> templates;
  const StepAgents({super.key, required this.wizard, required this.templates});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wizard,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('勾选需要的专家 agent（含产品经理）：'),
          const SizedBox(height: 8),
          for (final t in templates)
            CheckboxListTile(
              value: wizard.isSelected(t),
              onChanged: (_) => wizard.toggleTemplate(t),
              title: Text(t.role),
              subtitle: Text('${t.displayName} · ${t.ref}'),
            ),
        ],
      ),
    );
  }
}
