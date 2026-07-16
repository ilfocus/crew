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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('项目')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onNew,
        icon: const Icon(Icons.add),
        label: const Text('新建项目'),
      ),
      body: FutureBuilder<List<ProjectEntry>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text('还没有项目。点右下角"新建项目"开始装配你的 Crew。'),
            );
          }
          return ListView(
            children: [
              for (final e in items)
                ListTile(
                  leading: const Icon(Icons.workspaces_outline),
                  title: Text(e.name),
                  subtitle: Text('${e.path} · ${e.repoCount} 目录 · ${e.agentCount} agent'),
                  onTap: () => widget.onOpen(e),
                  trailing: widget.expertPoolService != null
                      ? IconButton(
                          icon: const Icon(Icons.psychology),
                          tooltip: '提炼专家',
                          onPressed: () => _onPublish(e),
                        )
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}
