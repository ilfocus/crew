// crew_gui/lib/ui/expert_pool_page.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import '../services/expert_pool_service.dart';
import 'expert_detail_page.dart';

class ExpertPoolPage extends StatefulWidget {
  final ExpertPoolService service;
  /// 点击项目专家卡片时触发；由父级在内容区域内渲染详情页以保留左侧菜单。
  /// 为 null 时回退到 Navigator.push（全屏覆盖左侧菜单）。
  final void Function(ExpertSummary summary, Directory expertDir)? onOpenExpert;
  const ExpertPoolPage({
    super.key,
    required this.service,
    this.onOpenExpert,
  });

  @override
  State<ExpertPoolPage> createState() => _ExpertPoolPageState();
}

class _ExpertPoolPageState extends State<ExpertPoolPage> {
  late Future<List<ExpertSummary>> _future;

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

  void _showApplyDialog(ExpertSummary domain) {
    showDialog(
      context: context,
      builder: (_) => _ApplyExpertDialog(
        service: widget.service,
        domain: domain,
      ),
    ).then((_) => _refresh());
  }

  Future<void> _deleteDomain(ExpertSummary domain) async {
    final ok = await _confirmDelete(
      title: '删除领域专家',
      message: '确定删除领域专家「${domain.displayName}」？\n'
          '该 domain 下所有专家文件将被永久移除。',
    );
    if (ok != true) return;
    await widget.service.deleteDomain(domain.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除领域专家「${domain.displayName}」')),
    );
    _refresh();
  }

  Future<void> _deleteProjectExpert(ExpertSummary expert) async {
    final ok = await _confirmDelete(
      title: '删除项目专家',
      message: '确定删除项目专家「${expert.displayName}」？\n'
          '该项目的专家文件将被永久移除。',
    );
    if (ok != true) return;
    await widget.service.deleteProject(expert.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除项目专家「${expert.displayName}」')),
    );
    _refresh();
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
            child: const Text('删除'),
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: FutureBuilder<List<ExpertSummary>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return const _EmptyPool();
              }
              final domains =
                  items.where((e) => e.kind == ExpertKind.domain).toList();
              final projects =
                  items.where((e) => e.kind == ExpertKind.project).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (domains.isNotEmpty) ...[
                    const _GroupLabel('领域专家'),
                    const SizedBox(height: 8),
                    for (final d in domains) ...[
                      _DomainCard(
                        summary: d,
                        onApply: () => _showApplyDialog(d),
                        onDelete: () => _deleteDomain(d),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (projects.isNotEmpty) const SizedBox(height: 12),
                  ],
                  if (projects.isNotEmpty) ...[
                    const _GroupLabel('项目专家'),
                    const SizedBox(height: 8),
                    for (final p in projects) ...[
                      _ProjectExpertCard(
                        summary: p,
                        poolRoot: widget.service.pool.root.path,
                        onOpenExpert: widget.onOpenExpert,
                        onDelete: () => _deleteProjectExpert(p),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
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
              '从项目列表中「提炼专家」来填充',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  final ExpertSummary summary;
  final VoidCallback onApply;
  final VoidCallback onDelete;
  const _DomainCard({
    required this.summary,
    required this.onApply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: theme.colorScheme.primary,
                size: 18,
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
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'domain: ${summary.id} · v${summary.version}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onApply,
              child: const Text('应用到目录'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: '删除',
              color: theme.colorScheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectExpertCard extends StatelessWidget {
  final ExpertSummary summary;
  final String poolRoot;
  final void Function(ExpertSummary summary, Directory expertDir)?
      onOpenExpert;
  final VoidCallback onDelete;
  const _ProjectExpertCard({
    required this.summary,
    required this.poolRoot,
    this.onOpenExpert,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.workspaces_outline,
                  color: theme.colorScheme.secondary,
                  size: 18,
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
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    // projectId 可能含斜杠（如 github.com/foo/bar），对应 experts/projects/<projectId>/
    final dir = Directory('$poolRoot/projects/${summary.id}');
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

class _ApplyExpertDialog extends StatefulWidget {
  final ExpertPoolService service;
  final ExpertSummary domain;
  const _ApplyExpertDialog({
    required this.service,
    required this.domain,
  });

  @override
  State<_ApplyExpertDialog> createState() => _ApplyExpertDialogState();
}

class _ApplyExpertDialogState extends State<_ApplyExpertDialog> {
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
    if (path.isEmpty || agent.isEmpty) {
      setState(() => _error = '请填写目标目录和 agent 名称');
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
      domain: widget.domain.id,
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
        SnackBar(content: Text('已应用领域专家到 $path')),
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
      title: Text('应用领域专家：${widget.domain.displayName}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _pathCtrl,
                decoration: const InputDecoration(
                  labelText: '目标目录路径',
                  hintText: '/path/to/project',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _agentCtrl,
                decoration: const InputDecoration(
                  labelText: 'agent 名称',
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
