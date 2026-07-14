// crew_gui/lib/ui/wizard/wizard_page.dart
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../models/project_entry.dart';
import '../../services/directory_picker.dart';
import '../../services/project_store.dart';
import '../../services/template_repository.dart';
import '../../services/workspace_opener.dart';
import '../../state/generation_controller.dart';
import '../../state/wizard_controller.dart';
import '../../state/wizard_step.dart';
import 'step_agents.dart';
import 'step_assign.dart';
import 'step_directories.dart';
import 'step_done.dart';
import 'step_preview.dart';
import 'step_targets.dart';

class WizardPage extends StatefulWidget {
  final WizardController wizard;
  final TemplateRepository templates;
  final DirectoryPicker picker;
  final GenerationController generation;
  final WorkspaceOpener opener;
  final ProjectStore store;
  final VoidCallback onDone;
  const WizardPage({
    super.key,
    required this.wizard,
    required this.templates,
    required this.picker,
    required this.generation,
    required this.opener,
    required this.store,
    required this.onDone,
  });

  @override
  State<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends State<WizardPage> {
  int _index = 0;

  List<WizardStep> get _order => const [
        WizardStep.directories,
        WizardStep.agents,
        WizardStep.assign,
        WizardStep.targets,
        WizardStep.preview,
        WizardStep.done,
      ];

  String _workspaceRoot() =>
      p.join(widget.wizard.workspaceParent, widget.wizard.projectName);

  String _today() {
    final n = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final wizard = widget.wizard;
    return Scaffold(
      appBar: AppBar(title: const Text('新建 Crew 项目')),
      body: ListenableBuilder(
        listenable: wizard,
        builder: (context, _) {
          final current = _order[_index];
          return Stepper(
            currentStep: _index,
            controlsBuilder: (context, details) {
              // Stepper 为每个 step 都调用 controlsBuilder（在 AnimatedCrossFade
              // 里维持状态）。只给当前步渲染实际按钮，避免 find.text 误匹配。
              if (details.stepIndex != details.currentStep) {
                return const SizedBox.shrink();
              }
              final isLast = details.stepIndex == _order.length - 1;
              return OverflowBar(
                spacing: 8,
                children: [
                  if (!isLast)
                    TextButton(
                      onPressed: details.onStepContinue,
                      child: const Text('下一步'),
                    ),
                  if (details.onStepCancel != null)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('上一步'),
                    ),
                ],
              );
            },
            onStepContinue: wizard.canProceed(current)
                ? () async {
                    if (current == WizardStep.preview) {
                      if (widget.generation.plan == null) return; // 需先生成预览
                      await widget.generation.confirmAndEmit(_workspaceRoot());
                      await widget.store.add(ProjectEntry(
                        name: wizard.projectName,
                        path: _workspaceRoot(),
                        createdAt: _today(),
                        repoCount: wizard.directories.length,
                        agentCount: wizard.selectedTemplates.length,
                      ));
                    }
                    if (_index < _order.length - 1) setState(() => _index++);
                  }
                : null,
            onStepCancel:
                _index > 0 ? () => setState(() => _index--) : null,
            steps: [
              Step(
                title: const Text('目录'),
                isActive: _index >= 0,
                content: StepDirectories(
                    wizard: wizard, picker: widget.picker),
              ),
              Step(
                title: const Text('专家'),
                isActive: _index >= 1,
                content: StepAgents(
                    wizard: wizard, templates: widget.templates.all),
              ),
              Step(
                title: const Text('关联'),
                isActive: _index >= 2,
                content: StepAssign(wizard: wizard),
              ),
              Step(
                title: const Text('目标'),
                isActive: _index >= 3,
                content: StepTargets(wizard: wizard),
              ),
              Step(
                title: const Text('预览'),
                isActive: _index >= 4,
                content: StepPreview(
                  wizard: wizard,
                  generation: widget.generation,
                  picker: widget.picker,
                ),
              ),
              Step(
                title: const Text('完成'),
                isActive: _index >= 5,
                content: StepDone(
                  workspacePath: _workspaceRoot(),
                  opener: widget.opener,
                  cliTool: wizard.cliTool,
                  onFinish: widget.onDone,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
