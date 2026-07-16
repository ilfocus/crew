// crew_gui/lib/ui/expert_pool_page.dart
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import '../services/expert_pool_service.dart';

class ExpertPoolPage extends StatefulWidget {
  final ExpertPoolService service;
  const ExpertPoolPage({super.key, required this.service});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('专家池'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<ExpertSummary>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text('专家池为空。从项目列表中"提炼专家"来填充。'),
            );
          }
          final domains =
              items.where((e) => e.kind == ExpertKind.domain).toList();
          final projects =
              items.where((e) => e.kind == ExpertKind.project).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (domains.isNotEmpty) ...[
                _SectionTitle('领域专家'),
                const SizedBox(height: 8),
                for (final d in domains)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.auto_awesome,
                            color: theme.colorScheme.primary, size: 20),
                      ),
                      title: Text(d.displayName),
                      subtitle: Text('domain: ${d.id} · v${d.version}'),
                      trailing: FilledButton.tonal(
                        onPressed: () => _showApplyDialog(d),
                        child: const Text('应用到目录'),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              if (projects.isNotEmpty) ...[
                _SectionTitle('项目专家'),
                const SizedBox(height: 8),
                for (final p in projects)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Icon(Icons.workspaces_outline,
                            color: theme.colorScheme.secondary, size: 20),
                      ),
                      title: Text(p.displayName),
                      subtitle: Text('id: ${p.id} · v${p.version}'),
                    ),
                  ),
              ],
            ],
          );
        },
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _pathCtrl,
              decoration: const InputDecoration(
                labelText: '目标目录路径',
                border: OutlineInputBorder(),
                hintText: '/path/to/project',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _agentCtrl,
              decoration: const InputDecoration(
                labelText: 'agent 名称',
                border: OutlineInputBorder(),
                hintText: '如 ios',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reposCtrl,
              decoration: const InputDecoration(
                labelText: '仓库（逗号分隔）',
                border: OutlineInputBorder(),
                hintText: '~/proj/repo1, ~/proj/repo2',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 8),
              Text(_result!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13)),
            ],
          ],
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
