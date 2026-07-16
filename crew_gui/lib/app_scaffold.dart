// crew_gui/lib/app_scaffold.dart
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import 'services/directory_picker.dart';
import 'services/expert_pool_service.dart';
import 'services/project_store.dart';
import 'services/template_repository.dart';
import 'services/workspace_opener.dart';
import 'state/generation_controller.dart';
import 'state/wizard_controller.dart';
import 'ui/expert_pool_page.dart';
import 'ui/experts_page.dart';
import 'ui/home_page.dart';
import 'ui/wizard/wizard_page.dart';

class AppScaffold extends StatefulWidget {
  final ProjectStore store;
  final TemplateRepository templates;
  final DirectoryPicker picker;
  final WorkspaceOpener opener;
  final GenerationController Function() generationFactory;
  final String cliTool;
  final ExpertPoolService? expertPoolService;
  const AppScaffold({
    super.key,
    required this.store,
    required this.templates,
    required this.picker,
    required this.opener,
    required this.generationFactory,
    this.cliTool = 'claude',
    this.expertPoolService,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

enum _NavTab { newProject, experts, projects, pool }

class _AppScaffoldState extends State<AppScaffold> {
  _NavTab _tab = _NavTab.projects;
  WizardController? _wizard;
  GenerationController? _generation;
  late final ExpertPoolService _poolService;

  @override
  void initState() {
    super.initState();
    _poolService =
        widget.expertPoolService ?? ExpertPoolService.defaultForTool(widget.cliTool);
  }

  void _startNew() {
    setState(() {
      _wizard = WizardController();
      _generation = widget.generationFactory();
      _tab = _NavTab.newProject;
    });
  }

  void _onWizardDone() {
    setState(() {
      _wizard = null;
      _generation = null;
      _tab = _NavTab.projects;
    });
  }

  Widget _buildContent() {
    switch (_tab) {
      case _NavTab.newProject:
        _wizard ??= WizardController();
        _generation ??= widget.generationFactory();
        return WizardPage(
          wizard: _wizard!,
          templates: widget.templates,
          picker: widget.picker,
          generation: _generation!,
          opener: widget.opener,
          store: widget.store,
          onDone: _onWizardDone,
        );
      case _NavTab.experts:
        return ExpertsPage(
          templates: widget.templates,
          onAiRefine: ({
            required String role,
            required String currentPrompt,
            required String instruction,
          }) async {
            final runner = CliRunner(tool: widget.cliTool);
            final prompt = '你是 prompt 优化助手。\n'
                '当前角色：$role\n'
                '当前 prompt：\n$currentPrompt\n\n'
                '用户指令：$instruction\n\n'
                '请根据用户指令优化上述 prompt，直接输出优化后的完整 prompt，不要输出其他内容。';
            final result = await runner.probe(
              workingDir: '.',
              prompt: prompt,
              template: const AgentTemplate(
                id: 'prompt-optimizer', version: 1, defaultName: 'optimizer',
                displayName: '优化器', role: 'prompt优化',
                probePrompt: '', matchGlobs: [],
              ),
            );
            if (!result.ok) throw Exception('CLI 返回非零: ${result.exitCode}');
            return result.rawOutput.trim();
          },
        );
      case _NavTab.projects:
        return HomePage(
          store: widget.store,
          onNew: _startNew,
          onOpen: (e) => widget.opener.openFolder(e.path),
          expertPoolService: _poolService,
        );
      case _NavTab.pool:
        return ExpertPoolPage(service: _poolService);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          // 左侧导航栏
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                right: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: Column(
              children: [
                // 应用标题
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(Icons.groups_rounded,
                          size: 24, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text('Crew',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 导航项
                _SidebarItem(
                  icon: Icons.add_circle_outline,
                  label: '新建项目',
                  selected: _tab == _NavTab.newProject,
                  onTap: _startNew,
                ),
                _SidebarItem(
                  icon: Icons.people_outline,
                  label: '专家',
                  selected: _tab == _NavTab.experts,
                  onTap: () => setState(() => _tab = _NavTab.experts),
                ),
                _SidebarItem(
                  icon: Icons.folder_outlined,
                  label: '项目',
                  selected: _tab == _NavTab.projects,
                  onTap: () => setState(() => _tab = _NavTab.projects),
                ),
                _SidebarItem(
                  icon: Icons.pool_outlined,
                  label: '专家池',
                  selected: _tab == _NavTab.pool,
                  onTap: () => setState(() => _tab = _NavTab.pool),
                ),
              ],
            ),
          ),
          // 右侧内容区
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color:
                selected ? theme.colorScheme.primaryContainer : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
