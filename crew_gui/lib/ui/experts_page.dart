// crew_gui/lib/ui/experts_page.dart
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/template_preview.dart';
import '../services/template_repository.dart';

/// AI 辅助编辑回调：传入角色、当前 prompt、用户指令，返回优化后的 prompt
typedef AiRefineCallback = Future<String> Function({
  required String role,
  required String currentPrompt,
  required String instruction,
});

class ExpertsPage extends StatefulWidget {
  final TemplateRepository templates;
  final AiRefineCallback? onAiRefine;
  const ExpertsPage({super.key, required this.templates, this.onAiRefine});

  @override
  State<ExpertsPage> createState() => _ExpertsPageState();
}

class _ExpertsPageState extends State<ExpertsPage> {
  void _refresh() => setState(() {});

  void _openEditor(AgentTemplate? template, {bool isNew = false}) {
    final t = template ?? widget.templates.cloneBuiltin(
      const AgentTemplate(
        id: 'custom', version: 1, defaultName: 'custom', displayName: '新专家',
        role: '自定义角色', probePrompt: '', matchGlobs: [],
      ),
    );
    final isBuiltin = template != null && widget.templates.isBuiltin(template);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertEditPage(
          initial: t,
          repository: widget.templates,
          isBuiltinOriginal: isBuiltin,
          isNew: isNew,
          onAiRefine: widget.onAiRefine,
          onChanged: _refresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = widget.templates.all;
    return Scaffold(
      appBar: AppBar(
        title: const Text('专家'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '新建专家',
            onPressed: () => _openEditor(null, isNew: true),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: all.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final t = all[i];
              return _ExpertCard(
                template: t,
                isBuiltin: widget.templates.isBuiltin(t),
                onTap: () => _openEditor(t),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  final AgentTemplate template;
  final bool isBuiltin;
  final VoidCallback onTap;
  const _ExpertCard({
    required this.template,
    required this.isBuiltin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = template.displayName.isNotEmpty
        ? template.displayName.characters.first
        : '?';
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isBuiltin
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: isBuiltin
                        ? theme.colorScheme.primary
                        : theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${template.displayName}（${template.role}）',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Badge(
                          isBuiltin ? '内置' : '自定义',
                          isBuiltin
                              ? theme.colorScheme.secondaryContainer
                              : theme.colorScheme.tertiaryContainer,
                          isBuiltin
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.onTertiaryContainer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID: ${template.id} · 匹配: ${template.matchGlobs.isEmpty ? "通用" : template.matchGlobs.join(", ")}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ─── 编辑页 ──────────────────────────────────────────────

class ExpertEditPage extends StatefulWidget {
  final AgentTemplate initial;
  final TemplateRepository repository;
  final bool isBuiltinOriginal;
  final bool isNew;
  final AiRefineCallback? onAiRefine;
  final VoidCallback onChanged;

  const ExpertEditPage({
    super.key,
    required this.initial,
    required this.repository,
    required this.isBuiltinOriginal,
    required this.isNew,
    this.onAiRefine,
    required this.onChanged,
  });

  @override
  State<ExpertEditPage> createState() => _ExpertEditPageState();
}

class _ExpertEditPageState extends State<ExpertEditPage> {
  late TextEditingController _displayNameCtrl;
  late TextEditingController _roleCtrl;
  late TextEditingController _probePromptCtrl;
  late TextEditingController _matchGlobsCtrl;
  late TextEditingController _idCtrl;
  late TextEditingController _defaultNameCtrl;
  late TextEditingController _personalityCtrl;
  late TextEditingController _principlesCtrl;

  bool get _isCustomEditable => !widget.isBuiltinOriginal || widget.isNew;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _displayNameCtrl = TextEditingController(text: t.displayName);
    _roleCtrl = TextEditingController(text: t.role);
    _probePromptCtrl = TextEditingController(text: t.probePrompt);
    _matchGlobsCtrl = TextEditingController(text: t.matchGlobs.join(', '));
    _idCtrl = TextEditingController(text: t.id);
    _defaultNameCtrl = TextEditingController(text: t.defaultName);
    _personalityCtrl = TextEditingController(text: t.personality);
    _principlesCtrl = TextEditingController(text: t.principles.join(', '));
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _roleCtrl.dispose();
    _probePromptCtrl.dispose();
    _matchGlobsCtrl.dispose();
    _idCtrl.dispose();
    _defaultNameCtrl.dispose();
    _personalityCtrl.dispose();
    _principlesCtrl.dispose();
    super.dispose();
  }

  AgentTemplate _buildFromForm() {
    return AgentTemplate(
      id: _idCtrl.text.trim(),
      version: widget.initial.version,
      defaultName: _defaultNameCtrl.text.trim(),
      displayName: _displayNameCtrl.text.trim(),
      role: _roleCtrl.text.trim(),
      probePrompt: _probePromptCtrl.text,
      matchGlobs: _matchGlobsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      personality: _personalityCtrl.text.trim(),
      principles: _principlesCtrl.text
          .split(RegExp(r'[,\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _save() async {
    final t = _buildFromForm();
    await widget.repository.updateCustom(t);
    widget.onChanged();
    if (mounted) Navigator.of(context).pop();
  }

  /// 弹出预览面板：显示用当前表单值渲染的 md 文件清单与内容。
  ///
  /// 这是「渲染产物」预览——不依赖具体项目，不落盘，直接在内存中
  /// 用 TemplatePreview 渲染 `.claude/agents/<name>.md`、`.codex/agents/<name>.toml`、
  /// `memory/<name>/MEMORY.md`、`memory/<name>/project-notes.md`。
  void _showPreview() {
    final t = _buildFromForm();
    final preview = const TemplatePreview();
    final name = t.defaultName.isEmpty ? 'agent' : t.defaultName;
    final entries = <_PreviewEntry>[
      _PreviewEntry(
        relativePath: '.claude/agents/$name.md',
        label: '$name.md (claude)',
        group: 'Agent 配置',
        content: preview.renderClaudeAgent(t),
      ),
      _PreviewEntry(
        relativePath: '.codex/agents/$name.toml',
        label: '$name.toml (codex)',
        group: 'Agent 配置',
        content: preview.renderCodexAgent(t),
      ),
      _PreviewEntry(
        relativePath: 'memory/$name/MEMORY.md',
        label: 'MEMORY.md',
        group: '记忆',
        content: preview.renderMemoryIndex(t),
      ),
      _PreviewEntry(
        relativePath: 'memory/$name/project-notes.md',
        label: 'project-notes.md',
        group: '记忆',
        content: preview.renderProjectNotes(t),
      ),
    ];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TemplatePreviewPage(
          title: t.displayName.isEmpty ? '预览' : '预览 · ${t.displayName}',
          entries: entries,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    await widget.repository.removeCustom(widget.initial.id);
    widget.onChanged();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _aiRefine() async {
    if (widget.onAiRefine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 辅助不可用，请先配置 CLI 工具')),
      );
      return;
    }
    final instruction = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('AI 辅助优化'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前角色：${_roleCtrl.text}'),
              const SizedBox(height: 8),
              const Text('描述你想要的调整方向，例如：'),
              const Text('· 更关注 SwiftUI 和 Combine 框架',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Text('· 增加 CI/CD 流程的检查',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Text('· 适配 Flutter 跨平台项目',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '输入优化指令...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('优化'),
            ),
          ],
        );
      },
    );
    if (instruction == null || instruction.trim().isEmpty) return;

    setState(() {});
    try {
      final refined = await widget.onAiRefine!(
        role: _roleCtrl.text,
        currentPrompt: _probePromptCtrl.text,
        instruction: instruction,
      );
      _probePromptCtrl.text = refined;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 已优化 prompt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 优化失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '新建专家' : '编辑专家'),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview_outlined),
            tooltip: '预览生成文件',
            onPressed: _showPreview,
          ),
          if (widget.onAiRefine != null)
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded),
              tooltip: 'AI 辅助优化',
              onPressed: _aiRefine,
            ),
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (widget.isBuiltinOriginal && !widget.isNew)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('这是内置模板。编辑后会保存为自定义版本，覆盖原内置模板。'),
                      ),
                    ],
                  ),
                ),
              // 基本信息区
              const _SectionLabel('基本信息'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ID',
                        border: OutlineInputBorder(),
                        hintText: '如 ios-dev',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _defaultNameCtrl,
                      decoration: const InputDecoration(
                        labelText: '默认名称',
                        border: OutlineInputBorder(),
                        hintText: '如 ios',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _displayNameCtrl,
                      decoration: const InputDecoration(
                        labelText: '显示名称',
                        border: OutlineInputBorder(),
                        hintText: '如 小i',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _roleCtrl,
                      decoration: const InputDecoration(
                        labelText: '角色职责',
                        border: OutlineInputBorder(),
                        hintText: '如 iOS 开发工程师',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 人格与判断标准
              const _SectionLabel('人格与判断标准'),
              const SizedBox(height: 12),
              TextField(
                controller: _personalityCtrl,
                decoration: const InputDecoration(
                  labelText: '人格',
                  border: OutlineInputBorder(),
                  hintText: '严谨、重性能',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _principlesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '判断标准',
                  border: OutlineInputBorder(),
                  hintText: '逗号或换行分隔，如：主线程不做 IO, 依赖锁版本',
                ),
              ),
              const SizedBox(height: 28),

              // 匹配规则
              const _SectionLabel('匹配规则'),
              const SizedBox(height: 4),
              Text(
                '逗号分隔的 glob 模式，用于自动匹配项目目录（如 *.swift, Podfile）',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _matchGlobsCtrl,
                decoration: const InputDecoration(
                  labelText: '匹配 Glob',
                  border: OutlineInputBorder(),
                  hintText: '*.swift, Podfile, *.xcworkspace',
                ),
              ),
              const SizedBox(height: 28),

              // Probe Prompt
              const _SectionLabel('探查 Prompt'),
              const SizedBox(height: 4),
              Text(
                'AI 探查项目时使用的 prompt，定义专家如何分析代码库',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _probePromptCtrl,
                maxLines: 12,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '探查 prompt...',
                ),
              ),
              const SizedBox(height: 16),
              if (widget.onAiRefine != null)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('AI 辅助优化'),
                  onPressed: _aiRefine,
                ),

              const SizedBox(height: 32),
              // 底部操作
              Row(
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('保存'),
                    onPressed: _save,
                  ),
                  const SizedBox(width: 12),
                  if (!widget.isBuiltinOriginal && !widget.isNew)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('删除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('删除专家'),
                            content: Text('确定删除「${_displayNameCtrl.text}」？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) _delete();
                      },
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// 预览条目：相对路径 + 短标签 + 分组 + 内容字符串（不落盘）。
class _PreviewEntry {
  final String relativePath;
  final String label;
  final String group;
  final String content;
  const _PreviewEntry({
    required this.relativePath,
    required this.label,
    required this.group,
    required this.content,
  });
}

/// 模板渲染预览页：左右分栏，左侧文件列表，右侧内容。
class _TemplatePreviewPage extends StatefulWidget {
  final String title;
  final List<_PreviewEntry> entries;
  const _TemplatePreviewPage({
    required this.title,
    required this.entries,
  });

  @override
  State<_TemplatePreviewPage> createState() => _TemplatePreviewPageState();
}

class _TemplatePreviewPageState extends State<_TemplatePreviewPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entries.isEmpty ? null : widget.entries[_selected];
    // 按 group 分组
    final groups = <String, List<_PreviewEntry>>{};
    for (final e in widget.entries) {
      groups.putIfAbsent(e.group, () => []).add(e);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: '说明',
            onPressed: () => _showInfo(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 720;
          final fileList = _buildFileList(theme, groups);
          final contentPanel = _buildContentPanel(theme, entry);
          if (!wide) {
            return Column(
              children: [
                SizedBox(height: 140, child: fileList),
                const Divider(height: 1),
                Expanded(child: contentPanel),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 240, child: fileList),
              VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
              Expanded(child: contentPanel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFileList(
      ThemeData theme, Map<String, List<_PreviewEntry>> groups) {
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final g in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Text(
                g.key,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            for (final e in g.value) _buildFileTile(theme, e),
          ],
        ],
      ),
    );
  }

  Widget _buildFileTile(ThemeData theme, _PreviewEntry entry) {
    final idx = widget.entries.indexOf(entry);
    final selected = idx == _selected;
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selected = idx),
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
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

  Widget _buildContentPanel(ThemeData theme, _PreviewEntry? entry) {
    if (entry == null) {
      return Center(
        child: Text(
          '选择左侧文件查看内容',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
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
                    entry.relativePath,
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
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: entry.content));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('已复制内容到剪贴板'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                entry.content,
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

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于此预览'),
        content: const Text(
          '此预览用当前表单的值渲染专家生成后会产出的 md 文件。\n\n'
          '注意：模板本身没有探查字段（项目坐标/模块结构/技术栈/SDK/重难点等），'
          '这些部分在实际生成时会由 CLI 探查后填充，这里留空。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
