// crew_gui/lib/app_scaffold.dart
import 'dart:io';

import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import 'models/project_entry.dart';
import 'services/directory_picker.dart';
import 'services/expert_pool_service.dart';
import 'services/project_store.dart';
import 'services/template_repository.dart';
import 'services/workspace_opener.dart';
import 'state/generation_controller.dart';
import 'state/wizard_controller.dart';
import 'ui/expert_detail_page.dart';
import 'ui/expert_pool_page.dart';
import 'ui/experts_page.dart';
import 'ui/home_page.dart';
import 'ui/new_project_page.dart';
import 'ui/project_detail_page.dart';

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

// 桌面端侧边栏展开宽度；窄窗时折叠为图标轨
const _sidebarExpandedWidth = 240.0;
const _sidebarCollapsedWidth = 64.0;
const _sidebarBreakpoint = 720.0;

/// 专家详情视图：当非 null 时覆盖在当前 tab 内容之上，保留左侧菜单。
class _ExpertDetailView {
  final String title;
  final Directory expertDir;
  _ExpertDetailView({required this.title, required this.expertDir});
}

/// 专家编辑视图：当非 null 时覆盖在当前 tab 内容之上，保留左侧菜单。
class _ExpertEditView {
  final AgentTemplate template;
  final bool isBuiltinOriginal;
  final bool isNew;
  _ExpertEditView({
    required this.template,
    required this.isBuiltinOriginal,
    required this.isNew,
  });
}

class _AppScaffoldState extends State<AppScaffold> {
  _NavTab _tab = _NavTab.projects;
  WizardController? _wizard;
  GenerationController? _generation;
  late final ExpertPoolService _poolService;
  // 项目详情视图：当非 null 时覆盖在当前 tab 内容之上
  ProjectEntry? _projectDetail;
  // 专家池详情视图：当非 null 时覆盖在当前 tab 内容之上，保留左侧菜单
  _ExpertDetailView? _expertDetail;
  // 专家编辑视图：当非 null 时覆盖在当前 tab 内容之上，保留左侧菜单
  _ExpertEditView? _expertEdit;

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
      _projectDetail = null;
      _expertDetail = null;
      _expertEdit = null;
    });
  }

  void _onWizardDone() {
    setState(() {
      _wizard = null;
      _generation = null;
      _tab = _NavTab.projects;
      _projectDetail = null;
      _expertDetail = null;
      _expertEdit = null;
    });
  }

  void _openProject(ProjectEntry e) {
    setState(() {
      _projectDetail = e;
      _expertDetail = null;
      _expertEdit = null;
    });
  }

  void _openExpert(ExpertSummary summary, Directory expertDir) {
    setState(() {
      _expertDetail = _ExpertDetailView(
        title: summary.displayName,
        expertDir: expertDir,
      );
      _projectDetail = null;
      _expertEdit = null;
    });
  }

  void _openExpertEditor(
      AgentTemplate template, bool isBuiltinOriginal, bool isNew) {
    setState(() {
      _expertEdit = _ExpertEditView(
        template: template,
        isBuiltinOriginal: isBuiltinOriginal,
        isNew: isNew,
      );
      _projectDetail = null;
      _expertDetail = null;
    });
  }

  /// AI 辅助优化 prompt 的回调（专家列表页与编辑页共用）。
  Future<String> _aiRefine({
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
  }

  Widget _buildContent() {
    // 专家编辑视图：在内容区渲染，保留左侧菜单
    if (_expertEdit != null) {
      return ExpertEditPage(
        initial: _expertEdit!.template,
        repository: widget.templates,
        isBuiltinOriginal: _expertEdit!.isBuiltinOriginal,
        isNew: _expertEdit!.isNew,
        onAiRefine: _aiRefine,
        onChanged: () {},
        onBack: () => setState(() => _expertEdit = null),
      );
    }
    // 专家池详情视图：在内容区渲染，保留左侧菜单
    if (_expertDetail != null) {
      return ExpertDetailPage(
        title: _expertDetail!.title,
        expertDir: _expertDetail!.expertDir,
        onBack: () => setState(() => _expertDetail = null),
      );
    }
    // 项目详情优先级最高
    if (_projectDetail != null) {
      return ProjectDetailPage(
        entry: _projectDetail!,
        opener: widget.opener,
        onBack: () => setState(() => _projectDetail = null),
      );
    }
    switch (_tab) {
      case _NavTab.newProject:
        _wizard ??= WizardController();
        _generation ??= widget.generationFactory();
        return NewProjectPage(
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
          onAiRefine: _aiRefine,
          onOpenEditor: _openExpertEditor,
        );
      case _NavTab.projects:
        return HomePage(
          store: widget.store,
          onNew: _startNew,
          onOpen: _openProject,
          expertPoolService: _poolService,
        );
      case _NavTab.pool:
        return ExpertPoolPage(
          service: _poolService,
          onOpenExpert: _openExpert,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 响应式：宽窗展开侧边栏，窄窗折叠为图标轨
          final expanded = constraints.maxWidth > _sidebarBreakpoint;
          // 侧栏选中态：在详情视图中高亮对应的来源 tab
          final activeTab = _projectDetail != null
              ? _NavTab.projects
              : _expertDetail != null
                  ? _NavTab.pool
                  : _expertEdit != null
                      ? _NavTab.experts
                      : _tab;
          return Row(
            children: [
              _Sidebar(
                tab: activeTab,
                expanded: expanded,
                cliTool: widget.cliTool,
                onNew: _startNew,
                onSelect: (t) {
                  setState(() {
                    _projectDetail = null;
                    _expertDetail = null;
                    _expertEdit = null;
                    _tab = t;
                  });
                },
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(child: _buildContent()),
            ],
          );
        },
      ),
    );
  }
}

/// 侧边栏：品牌区 + 导航 + 底部 CLI 状态
class _Sidebar extends StatelessWidget {
  final _NavTab tab;
  final bool expanded;
  final String cliTool;
  final VoidCallback onNew;
  final ValueChanged<_NavTab> onSelect;
  const _Sidebar({
    required this.tab,
    required this.expanded,
    required this.cliTool,
    required this.onNew,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: expanded ? _sidebarExpandedWidth : _sidebarCollapsedWidth,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrandHeader(expanded: expanded),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: [
                _NavItem(
                  icon: Icons.add_circle_outline_rounded,
                  label: '新建项目',
                  expanded: expanded,
                  selected: tab == _NavTab.newProject,
                  onTap: onNew,
                ),
                _NavItem(
                  icon: Icons.people_outline_rounded,
                  label: '专家',
                  expanded: expanded,
                  selected: tab == _NavTab.experts,
                  onTap: () => onSelect(_NavTab.experts),
                ),
                _NavItem(
                  icon: Icons.folder_outlined,
                  label: '项目',
                  expanded: expanded,
                  selected: tab == _NavTab.projects,
                  onTap: () => onSelect(_NavTab.projects),
                ),
                _NavItem(
                  icon: Icons.workspace_premium_outlined,
                  label: '专家池',
                  expanded: expanded,
                  selected: tab == _NavTab.pool,
                  onTap: () => onSelect(_NavTab.pool),
                ),
              ],
            ),
          ),
          if (expanded) _SidebarFooter(cliTool: cliTool),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final bool expanded;
  const _BrandHeader({required this.expanded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.groups_rounded, size: 18, color: theme.colorScheme.onPrimary),
    );
    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: logo),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Crew',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                Text(
                  'Multi-agent crew builder',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedBg = theme.colorScheme.primaryContainer;
    final selectedFg = theme.colorScheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: theme.colorScheme.surfaceContainerHigh
              .withValues(alpha: selected ? 0 : 0.6),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: 10,
            ),
            child: expanded
                ? Row(
                    children: [
                      Icon(icon,
                          size: 18,
                          color: selected
                              ? selectedFg
                              : theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected
                                ? selectedFg
                                : theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(icon,
                        size: 20,
                        color: selected
                            ? selectedFg
                            : theme.colorScheme.onSurfaceVariant),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final String cliTool;
  const _SidebarFooter({required this.cliTool});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CLI · $cliTool',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '已就绪',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
