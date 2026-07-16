// crew_core/lib/src/runner/distill_parser.dart
import 'dart:convert';
import '../models/expert.dart';
import 'probe_parser.dart';

class DistillResult {
  final String domainNotes;
  final List<MemoryEntry> playbooks;
  const DistillResult(this.domainNotes, this.playbooks);
}

/// 解析 distill 原始输出为 [DistillResult]。
///
/// 期望 JSON 形如：
///   { "domainNotes": String, "playbooks": [{ "path": String, "content": String }] }
/// 与 [parseProbe] 一致，支持输出被散文 / ```json 包裹。
/// 找不到 JSON 对象时抛出 [FormatException]。
DistillResult parseDistill(String rawOutput) {
  final jsonText = extractFirstJsonObject(rawOutput);
  if (jsonText == null) {
    throw FormatException('distill 输出中未找到 JSON 对象', rawOutput);
  }
  final map = jsonDecode(jsonText) as Map<String, dynamic>;

  final notes = map['domainNotes']?.toString() ?? '';
  final playbookList = (map['playbooks'] as List?) ?? const <dynamic>[];
  final playbooks = <MemoryEntry>[];
  for (final item in playbookList) {
    if (item is Map) {
      playbooks.add(MemoryEntry(
        item['path']?.toString() ?? '',
        item['content']?.toString() ?? '',
      ));
    }
  }
  return DistillResult(notes, playbooks);
}
