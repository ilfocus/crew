// crew_gui/lib/ui/expert_detail_page.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import '../services/workspace_browser.dart';
import 'widgets/markdown_file_viewer.dart';

/// 专家池中某个专家的详情页：显示该专家的 spec 元信息 + md 文件列表与内容。
///
/// 用于「项目专家」点击查看详情。专家目录结构由 ExpertPoolAdapter 生成：
/// IDENTITY.md / COMPETENCE.md / memory/*.md / memory/solved/* / memory/playbooks/*
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
  Expert? _expert;

  @override
  void initState() {
    super.initState();
    _browser = ExpertPoolBrowser(widget.expertDir);
    _expert = _browser.loadExpert();
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
              _expert = _browser.loadExpert();
            }),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_expert != null) _buildHeader(theme, _expert!),
          Expanded(
            child: MarkdownFileViewer(
              entries: _browser.listFiles(),
              emptyHint: '该专家目录下没有 markdown 文件',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Expert e) {
    final spec = e.spec;
    final initial = spec.displayName.isNotEmpty
        ? spec.displayName.characters.first
        : '?';
    final isProject = e.kind == ExpertKind.project;
    final idLabel = isProject
        ? '项目专家 · ${e.meta.projectId}'
        : '领域专家 · ${e.domain}';
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
              color: isProject
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initial.toUpperCase(),
              style: TextStyle(
                color: isProject
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
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
                        spec.displayName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
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
                const SizedBox(height: 4),
                Text(
                  idLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (spec.personality.isNotEmpty) ...[
                  const SizedBox(height: 2),
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
          ),
        ],
      ),
    );
  }
}
