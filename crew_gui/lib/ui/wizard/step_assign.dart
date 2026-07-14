// crew_gui/lib/ui/wizard/step_assign.dart
import 'package:flutter/material.dart';
import '../../state/wizard_controller.dart';

class StepAssign extends StatelessWidget {
  final WizardController wizard;
  const StepAssign({super.key, required this.wizard});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wizard,
      builder: (context, _) {
        final nonPm =
            wizard.selectedTemplates.where((t) => t.id != 'pm').toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('把每个专家关联到对应目录：')),
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('自动分配'),
                  onPressed: wizard.autoAssign,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final t in nonPm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t.displayName}（${t.role}）'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final dir in wizard.directories)
                          FilterChip(
                            label: Text(dir),
                            selected: (wizard.assignments[wizard.agentNameFor(t)] ??
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
