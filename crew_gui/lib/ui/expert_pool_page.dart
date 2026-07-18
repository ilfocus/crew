// crew_gui/lib/ui/expert_pool_page.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import '../services/expert_pool_service.dart';
import 'expert_detail_page.dart';

class ExpertPoolPage extends StatefulWidget {
  final ExpertPoolService service;
  /// 点击 agent 卡片时触发；由父级在内容区域内渲染详情页以保留左侧菜单。
  /// 为 null 时回退到 Navigator.push（全屏覆盖左侧菜单）。
  final void Function(AgentSummary summary, Directory expertDir)? onOpenExpert;
  const ExpertPoolPage({
    super.key,
    required this.service,
    this.onOpenExpert,
  });

  @override
  State<ExpertPoolPage> createState() => _ExpertPoolPageState();
}

class _ExpertPoolPageState extends State<ExpertPoolPage> {
  late Future<List<AgentSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.list();
  }

  void _refresh() {
    setState(() {
      _future = widget.service.list();
    });
  }

  void _showApplyDialog(AgentSummary summary) {
    if (summary.domains.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('agent「${summary.displayName}」暂无领域专长，无法应用')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _ApplyAgentDialog(
        service: widget.service,
        summary: summary,
      ),
    ).then((_) => _refresh());
  }

  Future<void> _deleteAgent(AgentSummary summary) async {
    final ok = await _confirmDelete(
      title: '删除 agent',
      message: '确定删除 agent「${summary.displayName}」？\n'
          '该 agent 下所有领域专长、项目经验、记忆文件将被永久移除。',
    );
    if (ok != true) return;
    await widget.service.deleteAgent(summary.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除 agent「${summary.displayName}」')),
    );
    _refresh();
  }

  Future<void> _migrate() async {
    final ok = await _confirmDelete(
      title: '迁移池布局',
      message: '把旧平铺布局迁移到新 agent 层级布局？\n'
          '首次迁移会备份当前池到 <pool>.bak，可重复运行（幂等）。',
    );
    if (ok != true) return;

    final outcome = await widget.service.migrate(version: 1);
    if (!mounted) return;
    if (outcome.isSuccess) {
      final msg = '已迁移 ${outcome.agents} agents、'
          '${outcome.projectsMoved} projects'
          '${outcome.backupPath != null ? '\n备份：${outcome.backupPath}' : ''}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('迁移失败：${outcome.error}')),
      );
    }
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('专家池'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: '迁移旧布局',
            onPressed: _migrate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: FutureBuilder<List<AgentSummary>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return const _EmptyPool();
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final s = items[i];
                  return _AgentCard(
                    summary: s,
                    poolRoot: widget.service.pool.root.path,
                    onApply: () => _showApplyDialog(s),
                    onDelete: () => _deleteAgent(s),
                    onOpenExpert: widget.onOpenExpert,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyPool extends StatelessWidget {
  const _EmptyPool();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '专家池为空',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '从项目列表中「提炼专家」来填充；或点右上角迁移旧布局',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final AgentSummary summary;
  final String poolRoot;
  final VoidCallback onApply;
  final VoidCallback onDelete;
  final void Function(AgentSummary summary, Directory expertDir)? onOpenExpert;
  const _AgentCard({
    required this.summary,
    required this.poolRoot,
    required this.onApply,
    required this.onDelete,
    this.onOpenExpert,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = summary.displayName.isNotEmpty
        ? summary.displayName.characters.first
        : '?';
    return Card(
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial.toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
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
                        Text(
                          summary.displayName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'id: ${summary.id} · v${summary.version}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    tooltip: '删除',
                    color: theme.colorScheme.error,
                    onPressed: onDelete,
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
              if (summary.domains.isNotEmpty || summary.projectCount > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (summary.domains.isNotEmpty)
                      for (final d in summary.domains)
                        _DomainChip(domain: d),
                    if (summary.projectCount > 0)
                      _ProjectCountChip(count: summary.projectCount),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.tonal(
                    onPressed: onApply,
                    child: const Text('应用到目录'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    final dir = Directory('$poolRoot/agents/${summary.id}');
    if (onOpenExpert != null) {
      onOpenExpert!(summary, dir);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertDetailPage(
          title: summary.displayName,
          expertDir: dir,
        ),
      ),
    );
  }
}

class _DomainChip extends StatelessWidget {
  final String domain;
  const _DomainChip({required this.domain});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 11,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            domain,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCountChip extends StatelessWidget {
  final int count;
  const _ProjectCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspaces_outline,
            size: 11,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            '$count 个项目',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyAgentDialog extends StatefulWidget {
  final ExpertPoolService service;
  final AgentSummary summary;
  const _ApplyAgentDialog({
    required this.service,
    required this.summary,
  });

  @override
  State<_ApplyAgentDialog> createState() => _ApplyAgentDialogState();
}

class _ApplyAgentDialogState extends State<_ApplyAgentDialog> {
  String? _selectedDomain;
  final _pathCtrl = TextEditingController();
  final _agentCtrl = TextEditingController();
  final _reposCtrl = TextEditingController();
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _pathCtrl.dispose();
    _agentCtrl.dispose();
    _reposCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final path = _pathCtrl.text.trim();
    final agent = _agentCtrl.text.trim();
    if (_selectedDomain == null || path.isEmpty || agent.isEmpty) {
      setState(() => _error = '请选择领域、填写目标目录和 agent 名称');
      return;
    }
    final repos = _reposCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    final outcome = await widget.service.useExpert(
      agentId: widget.summary.id,
      domain: _selectedDomain!,
      intoPath: path,
      agentName: agent,
      repos: repos,
    );
    if (!mounted) return;
    if (outcome.isSuccess) {
      setState(() {
        _loading = false;
        _result = '已写入 ${outcome.writtenPaths.length} 个文件';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已应用 agent「${widget.summary.displayName}」到 $path')),
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _loading = false;
        _error = outcome.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('应用 agent：${widget.summary.displayName}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '从 agent「${widget.summary.id}」选择一个领域专长实例化到目标 workspace。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedDomain,
                decoration: const InputDecoration(
                  labelText: '领域 *',
                  border: OutlineInputBorder(),
                ),
                items: widget.summary.domains
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedDomain = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pathCtrl,
                decoration: const InputDecoration(
                  labelText: '目标目录路径 *',
                  hintText: '/path/to/project',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _agentCtrl,
                decoration: const InputDecoration(
                  labelText: 'agent 名称 *',
                  hintText: '如 ios',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reposCtrl,
                decoration: const InputDecoration(
                  labelText: '仓库（逗号分隔）',
                  hintText: '~/proj/repo1, ~/proj/repo2',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _AlertBanner(text: _error!, isError: true),
              ],
              if (_result != null) ...[
                const SizedBox(height: 12),
                _AlertBanner(text: _result!, isError: false),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _loading ? null : _confirm,
          child: const Text('确认'),
        ),
      ],
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String text;
  final bool isError;
  const _AlertBanner({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
