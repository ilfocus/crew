// crew_gui/lib/ui/experts_page.dart
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
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
