// crew_gui/lib/ui/home_page.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:flutter/material.dart';
import '../models/project_entry.dart';
import '../services/expert_pool_service.dart';
import '../services/project_store.dart';
import 'publish_dialog.dart';

class HomePage extends StatefulWidget {
  final ProjectStore store;
  final VoidCallback onNew;
  final void Function(ProjectEntry) onOpen;
  final ExpertPoolService? expertPoolService;
  const HomePage({
    super.key,
    required this.store,
    required this.onNew,
    required this.onOpen,
    this.expertPoolService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<ProjectEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.load();
  }

  Future<void> _onPublish(ProjectEntry entry) async {
    final reader = WorkspaceReader(Directory(entry.path));
    final agents = await reader.readAgents();
    final names = agents.map((a) => a.spec.name).toList();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => PublishDialog(
        service: widget.expertPoolService!,
        workspacePath: entry.path,
        agentNames: names,
      ),
    );
  }

  Future<void> _deleteProject(ProjectEntry entry) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确定删除项目「${entry.name}」？\n'
            '该操作只从 Crew 列表中移除，不会删除磁盘上的项目文件。'),
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
    if (ok != true) return;
    await widget.store.remove(entry.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除项目「${entry.name}」')),
    );
    setState(() {
      _future = widget.store.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('项目'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
            onPressed: () => setState(() => _future = widget.store.load()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onNew,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建项目'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: FutureBuilder<List<ProjectEntry>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return _EmptyState(onNew: widget.onNew);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = items[i];
                  return _ProjectCard(
                    entry: e,
                    onOpen: () => widget.onOpen(e),
                    onPublish: widget.expertPoolService != null
                        ? () => _onPublish(e)
                        : null,
                    onDelete: () => _deleteProject(e),
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyState({required this.onNew});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '还没有项目',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '点右下角「新建项目」开始装配你的 Crew',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('新建项目'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectEntry entry;
  final VoidCallback onOpen;
  final VoidCallback? onPublish;
  final VoidCallback onDelete;
  const _ProjectCard({
    required this.entry,
    required this.onOpen,
    this.onPublish,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = entry.name.isNotEmpty ? entry.name.characters.first : '?';
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
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
                      entry.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _MetaChip(
                          icon: Icons.folder_outlined,
                          label: '${entry.repoCount} 目录',
                        ),
                        const SizedBox(width: 8),
                        _MetaChip(
                          icon: Icons.people_outline_rounded,
                          label: '${entry.agentCount} agent',
                        ),
                        if (entry.createdAt.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            label: entry.createdAt,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onPublish != null)
                IconButton(
                  icon: const Icon(Icons.psychology_rounded),
                  tooltip: '提炼专家',
                  onPressed: onPublish,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: '删除',
                color: theme.colorScheme.error,
                onPressed: onDelete,
              ),
              const SizedBox(width: 2),
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
