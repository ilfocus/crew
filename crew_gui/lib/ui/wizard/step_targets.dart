// crew_gui/lib/ui/wizard/step_targets.dart
import 'package:flutter/material.dart';
import '../../state/wizard_controller.dart';

class StepTargets extends StatelessWidget {
  final WizardController wizard;
  const StepTargets({super.key, required this.wizard});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListenableBuilder(
          listenable: wizard,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hint(text: '生成哪些工具的配置：'),
              const SizedBox(height: 10),
              _GroupCard(
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
                    color: Theme.of(context).colorScheme.outlineVariant,
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
              const SizedBox(height: 20),
              _Hint(text: '生成时用哪个 CLI 探查代码：'),
              const SizedBox(height: 10),
              _GroupCard(
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
                    color: Theme.of(context).colorScheme.outlineVariant,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 16,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}
