// crew_gui/lib/ui/expert_detail_page.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import '../services/workspace_browser.dart';
import 'widgets/markdown_file_viewer.dart';

/// 专家池中某个 agent 的详情页：显示该 agent 的 core 身份信息 + 全量 markdown 文件列表。
///
/// 用于 agent 卡片点击查看详情。Agent 目录结构由 AgentPoolAdapter 生成（spec §3）：
/// - agent.json（事实源：core + memory + meta）
/// - IDENTITY.md / RELATIONSHIPS.md / TOOLS.md（视图）
/// - memory/MEMORY.md、memory/short-term.md、memory/long-term/*
/// - domains/<d>/EXPERTISE.md + projects.md + playbooks/*
/// - projects/<p>/COMPETENCE.md + memory/project-notes.md + memory/solved/* + memory/playbooks/*
class ExpertDetailPage extends StatefulWidget {
  final String title;
  final Directory expertDir;
  /// 返回专家池的回调；为 null 时不显示返回按钮（例如被 Navigator 推入时由 leading 自动处理）。
  final VoidCallback? onBack;
  const ExpertDetailPage({
    super.key,
    required this.title,
    required this.expertDir,
    this.onBack,
  });

  @override
  State<ExpertDetailPage> createState() => _ExpertDetailPageState();
}

class _ExpertDetailPageState extends State<ExpertDetailPage> {
  late final ExpertPoolBrowser _browser;
  AgentProfile? _agent;

  @override
  void initState() {
    super.initState();
    _browser = ExpertPoolBrowser(widget.expertDir);
    _agent = _browser.loadAgent();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: '返回专家池',
                onPressed: widget.onBack,
              )
            : null,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
            onPressed: () => setState(() {
              _agent = _browser.loadAgent();
            }),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_agent != null) _buildHeader(theme, _agent!),
          Expanded(
            child: MarkdownFileViewer(
              entries: _browser.listFiles(),
              emptyHint: '该 agent 目录下没有 markdown 文件',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AgentProfile a) {
    final c = a.core;
    final initial = c.displayName.isNotEmpty
        ? c.displayName.characters.first
        : '?';
    final idLabel = 'id: ${c.id} · v${a.meta.version}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initial.toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.displayName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (c.role.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          c.role,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  idLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (c.personality.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '人格：${c.personality}',
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
          ),
        ],
      ),
    );
  }
}
