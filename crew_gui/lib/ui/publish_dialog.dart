// crew_gui/lib/ui/publish_dialog.dart
import 'package:flutter/material.dart';
import '../services/expert_pool_service.dart';

class PublishDialog extends StatefulWidget {
  final ExpertPoolService service;
  final String workspacePath;
  final List<String> agentNames;
  const PublishDialog({
    super.key,
    required this.service,
    required this.workspacePath,
    required this.agentNames,
  });

  @override
  State<PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<PublishDialog> {
  String? _agentName;
  String _retention = 'experience-only';
  String _source = 'opensource';
  final _domainCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _domainCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_agentName == null) {
      setState(() => _error = '请选择 agent');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final domainText = _domainCtrl.text.trim();
    final outcome = await widget.service.publish(
      workspacePath: widget.workspacePath,
      agentName: _agentName!,
      retention: _retention,
      source: _source,
      domain: domainText.isEmpty ? null : domainText,
      version: 1,
    );
    if (!mounted) return;
    if (outcome.isSuccess) {
      final msg = outcome.domainMerged != null
          ? '已提炼专家，已合并到领域 ${outcome.domainMerged}'
          : '已提炼专家';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
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
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('提炼专家'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(text: 'Agent'),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: _agentName,
                hint: const Text('选择 agent'),
                isExpanded: true,
                items: widget.agentNames
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (v) => setState(() => _agentName = v),
              ),
              const SizedBox(height: 16),
              _SectionLabel(text: '保留策略'),
              const SizedBox(height: 4),
              _GroupCard(
                children: [
                  for (final r in const [
                    ('full', '完整保留'),
                    ('experience-only', '仅保留经验'),
                    ('none', '不发布'),
                  ])
                    RadioListTile<String>(
                      value: r.$1,
                      groupValue: _retention,
                      title: Text(r.$2),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                      onChanged: (v) => setState(() => _retention = v!),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionLabel(text: '来源'),
              const SizedBox(height: 4),
              _GroupCard(
                children: [
                  for (final s in const [
                    ('opensource', '开源'),
                    ('private', '私有'),
                  ])
                    RadioListTile<String>(
                      value: s.$1,
                      groupValue: _source,
                      title: Text(s.$2),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                      onChanged: (v) => setState(() => _source = v!),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _domainCtrl,
                decoration: const InputDecoration(
                  labelText: '领域（可选）',
                  border: OutlineInputBorder(),
                  hintText: '如 quant',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 14, color: theme.colorScheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: theme.colorScheme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
