// crew_gui/lib/ui/widgets/markdown_file_viewer.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 一个 md 文件的描述项：相对路径 + 绝对路径 + 内容（可异步加载）。
class MarkdownFileEntry {
  final String relativePath;
  final String absolutePath;
  final String label; // 列表里展示的短标签
  final String? group; // 分组标签（如 "Agent 配置"、"记忆"）

  const MarkdownFileEntry({
    required this.relativePath,
    required this.absolutePath,
    required this.label,
    this.group,
  });
}

/// 左右分栏的 markdown 文件浏览器：左侧文件列表，右侧内容查看器。
///
/// 用于：
/// - 项目详情页：浏览 workspace 下专家的 md 文件
/// - 专家池项目专家详情：浏览 ~/.crew/experts/projects/<id>/ 下的 md 文件
class MarkdownFileViewer extends StatefulWidget {
  final List<MarkdownFileEntry> entries;
  final String emptyHint;
  const MarkdownFileViewer({
    super.key,
    required this.entries,
    this.emptyHint = '暂无 markdown 文件',
  });

  @override
  State<MarkdownFileViewer> createState() => _MarkdownFileViewerState();
}

class _MarkdownFileViewerState extends State<MarkdownFileViewer> {
  int _selected = 0;
  String? _content;
  bool _loading = false;
  String? _error;

  @override
  void didUpdateWidget(covariant MarkdownFileViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries) {
      _selected = 0;
      _loadSelected();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSelected();
  }

  Future<void> _loadSelected() async {
    if (widget.entries.isEmpty) {
      setState(() {
        _content = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    if (_selected >= widget.entries.length) _selected = 0;
    final entry = widget.entries[_selected];
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = File(entry.absolutePath);
      if (!file.existsSync()) {
        setState(() {
          _loading = false;
          _content = null;
          _error = '文件不存在：${entry.absolutePath}';
        });
        return;
      }
      final content = await file.readAsString();
      if (!mounted) return;
      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取失败：$e';
      });
    }
  }

  void _select(int i) {
    if (i == _selected) return;
    _selected = i;
    _loadSelected();
  }

  Future<void> _copy() async {
    if (_content == null) return;
    await Clipboard.setData(ClipboardData(text: _content!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制内容到剪贴板'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined,
                  size: 36,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                widget.emptyHint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // 按 group 分组
    final groups = <String?, List<MarkdownFileEntry>>{};
    for (final e in widget.entries) {
      groups.putIfAbsent(e.group, () => []).add(e);
    }
    final groupKeys = groups.keys.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 窄窗：列表与内容上下叠放（列表高度固定）
        // 宽窗：左右分栏
        final wide = constraints.maxWidth > 720;
        if (!wide) {
          return Column(
            children: [
              _buildFileList(theme, groups, groupKeys, height: 140),
              const Divider(height: 1),
              Expanded(child: _buildContentPanel(theme)),
            ],
          );
        }
        return Row(
          children: [
            _buildFileList(theme, groups, groupKeys, width: 240),
            VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
            Expanded(child: _buildContentPanel(theme)),
          ],
        );
      },
    );
  }

  Widget _buildFileList(
    ThemeData theme,
    Map<String?, List<MarkdownFileEntry>> groups,
    List<String?> groupKeys, {
    double? width,
    double? height,
  }) {
    final list = SizedBox(
      width: width,
      height: height,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final g in groupKeys) ...[
            if (g != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Text(
                  g,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            for (final e in groups[g]!) _buildFileTile(theme, e),
          ],
        ],
      ),
    );
    // 当 height 限制时，用 Container 包一层防止溢出
    if (height != null) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 1),
          ),
        ),
        child: list,
      );
    }
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: list,
    );
  }

  Widget _buildFileTile(ThemeData theme, MarkdownFileEntry entry) {
    final idx = widget.entries.indexOf(entry);
    final selected = idx == _selected;
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: () => _select(idx),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              Icon(
                Icons.description_outlined,
                size: 14,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentPanel(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_content == null) {
      return Center(
        child: Text(
          '选择左侧文件查看内容',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    final current =
        widget.entries.isNotEmpty ? widget.entries[_selected] : null;
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    current?.relativePath ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  tooltip: '复制内容',
                  onPressed: _copy,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _content!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
