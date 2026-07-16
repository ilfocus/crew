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
    return AlertDialog(
      title: const Text('提炼专家'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            DropdownButton<String>(
              value: _agentName,
              hint: const Text('选择 agent'),
              isExpanded: true,
              items: widget.agentNames
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) => setState(() => _agentName = v),
            ),
            const SizedBox(height: 12),
            const Text('保留策略',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _retention = v!),
              ),
            const SizedBox(height: 8),
            const Text('来源',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            for (final s in const [
              ('opensource', '开源'),
              ('private', '私有'),
            ])
              RadioListTile<String>(
                value: s.$1,
                groupValue: _source,
                title: Text(s.$2),
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _source = v!),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _domainCtrl,
              decoration: const InputDecoration(
                labelText: '领域（可选）',
                border: OutlineInputBorder(),
                hintText: '如 quant',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
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
