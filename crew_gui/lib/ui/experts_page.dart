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
            icon: const Icon(Icons.add),
            tooltip: '新建专家',
            onPressed: () => _openEditor(null, isNew: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final t in all)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    t.displayName.isNotEmpty
                        ? t.displayName.characters.first
                        : '?',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
                title: Row(
                  children: [
                    Text('${t.displayName}（${t.role}）'),
                    const SizedBox(width: 8),
                    if (widget.templates.isBuiltin(t))
                      _Badge('内置', theme.colorScheme.secondaryContainer)
                    else
                      _Badge('自定义', theme.colorScheme.tertiaryContainer),
                  ],
                ),
                subtitle: Text(
                  'ID: ${t.id} · 匹配: ${t.matchGlobs.isEmpty ? "通用" : t.matchGlobs.join(", ")}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openEditor(t),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
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
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _roleCtrl.dispose();
    _probePromptCtrl.dispose();
    _matchGlobsCtrl.dispose();
    _idCtrl.dispose();
    _defaultNameCtrl.dispose();
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
              const Text('· 增加对 CI/CD 流程的检查',
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
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'AI 辅助优化',
              onPressed: _aiRefine,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.isBuiltinOriginal && !widget.isNew)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('这是内置模板。编辑后会保存为自定义版本，覆盖原内置模板。'),
                  ),
                ],
              ),
            ),
          // 基本信息区
          _SectionTitle('基本信息'),
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
          const SizedBox(height: 24),

          // 匹配规则
          _SectionTitle('匹配规则'),
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
          const SizedBox(height: 24),

          // Probe Prompt
          _SectionTitle('探查 Prompt'),
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
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI 辅助优化'),
              onPressed: _aiRefine,
            ),

          const SizedBox(height: 32),
          // 底部操作
          Row(
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('保存'),
                onPressed: _save,
              ),
              const SizedBox(width: 12),
              if (!widget.isBuiltinOriginal && !widget.isNew)
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
