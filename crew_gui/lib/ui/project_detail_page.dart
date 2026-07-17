// crew_gui/lib/ui/project_detail_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/project_entry.dart';
import '../services/workspace_browser.dart';
import '../services/workspace_opener.dart';
import 'widgets/markdown_file_viewer.dart';

/// 项目详情页：展示项目元信息 + agent 列表 + 每个 agent 的 md 文件。
///
/// 布局：左侧 agent 名字列表，选中后右侧显示该 agent 的 md 文件列表 + 内容。
class ProjectDetailPage extends StatefulWidget {
  final ProjectEntry entry;
  final WorkspaceOpener opener;
  const ProjectDetailPage({
    super.key,
    required this.entry,
    required this.opener,
  });

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late final WorkspaceBrowser _browser;
  List<String> _agentNames = const [];
  String? _selected;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _browser = WorkspaceBrowser(Directory(widget.entry.path));
    try {
      _agentNames = _browser.listAgentNames();
      _selected = _agentNames.isEmpty ? null : _agentNames.first;
    } catch (e) {
      _loadError = '$e';
    }
  }

  void _refresh() {
    setState(() {
      try {
        _agentNames = _browser.listAgentNames();
        if (_selected == null || !_agentNames.contains(_selected)) {
          _selected = _agentNames.isEmpty ? null : _agentNames.first;
        }
        _loadError = null;
      } catch (e) {
        _loadError = '$e';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: '在文件管理器打开',
            onPressed: () => widget.opener.openFolder(widget.entry.path),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 36, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text('读取项目失败',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              Text(_loadError!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    // 项目元信息条
    final meta = Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaItem(
                    icon: Icons.folder_outlined,
                    label: widget.entry.path,
                    monospace: true),
                _MetaChip(
                    icon: Icons.people_outline_rounded,
                    label: '${widget.entry.agentCount} agent'),
                if (widget.entry.createdAt.isNotEmpty)
                  _MetaChip(
                      icon: Icons.calendar_today_outlined,
                      label: widget.entry.createdAt),
              ],
            ),
          ),
        ],
      ),
    );

    if (_agentNames.isEmpty) {
      return Column(
        children: [
          meta,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_search_outlined,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('该项目下没有发现 agent',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('生成专家后才能在这里查看 markdown 文件',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 主体：左侧 agent 列表 + 右侧 md 文件浏览器
    return Column(
      children: [
        meta,
        Expanded(
          child: Row(
            children: [
              _buildAgentList(theme),
              VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
              Expanded(child: _buildAgentDetail(theme)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgentList(ThemeData theme) {
    return Container(
      width: 200,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Text(
              'AGENTS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (final name in _agentNames) _buildAgentTile(theme, name),
        ],
      ),
    );
  }

  Widget _buildAgentTile(ThemeData theme, String name) {
    final selected = name == _selected;
    final spec = _browser.readSpec(name);
    final initial = (spec?.displayName.isNotEmpty ?? false)
        ? spec!.displayName.characters.first
        : (name.isNotEmpty ? name.characters.first : '?');
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selected = name),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial.toUpperCase(),
                  style: TextStyle(
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: selected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (spec != null && spec.role.isNotEmpty)
                      Text(
                        spec.role,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentDetail(ThemeData theme) {
    if (_selected == null) {
      return Center(
        child: Text(
          '选择左侧 agent 查看其 md 文件',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    final spec = _browser.readSpec(_selected!);
    final entries = _browser.listAgentFiles(_selected!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spec != null) _buildSpecHeader(theme, spec),
        Expanded(
          child: MarkdownFileViewer(
            entries: entries,
            emptyHint: '该 agent 没有可查看的 markdown 文件',
          ),
        ),
      ],
    );
  }

  Widget _buildSpecHeader(ThemeData theme, dynamic spec) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                spec.displayName,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  spec.role,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (spec.personality != null && spec.personality.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '人格：${spec.personality}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool monospace;
  const _MetaItem({
    required this.icon,
    required this.label,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
            fontFamily: monospace ? 'monospace' : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
