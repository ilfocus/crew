// crew_core/lib/src/expert/memory_eviction.dart
import '../models/agent_memory.dart';
import '../models/expert.dart' show MemoryEntry;

/// 收工归并：把 shortTerm 里值得沉淀的条目并入 longTerm，其余作废（spec §4.4）。
///
/// - [promoteToLongTerm]：由调用方（或 runner 蒸馏）标出要沉淀的条目；
///   本函数只做搬运 + 去重（按 path 去重，**已存在不覆盖**）。
/// - [dropFromShortTerm]：作废的行标识（按行精确匹配移除）。
/// - [maxShortTermEntries]：短期容量上限；超出时最旧的（最前面的）先被丢弃（FIFO）。
///
/// **长期只增不自动删**：本函数绝不从 longTerm 中移除任何条目；
/// 长期记忆的修正/删除走人工或收工蒸馏的"过时即改"约定。
///
/// 短期以"行"为条目（`short-term.md` 每行一条）。
AgentMemory consolidate({
  required AgentMemory memory,
  required List<MemoryEntry> promoteToLongTerm,
  required List<String> dropFromShortTerm,
  int maxShortTermEntries = 50,
}) {
  // 1. long-term：追加 promote（按 path 去重，已存在不覆盖）。
  //    输入侧的重复也一并去重，保留首次出现的。
  final existingPaths = <String>{};
  final mergedLongTerm = <MemoryEntry>[];
  for (final e in memory.longTerm) {
    if (existingPaths.add(e.path)) {
      mergedLongTerm.add(e);
    }
  }
  for (final e in promoteToLongTerm) {
    if (existingPaths.add(e.path)) {
      mergedLongTerm.add(e);
    }
  }

  // 2. short-term：移除 dropFromShortTerm 中匹配的行（精确匹配）。
  final dropSet = dropFromShortTerm.toSet();
  final List<String> filtered = memory.shortTerm.isEmpty
      ? const <String>[]
      : memory.shortTerm
          .split('\n')
          .where((l) => !dropSet.contains(l))
          .toList();

  // 3. FIFO eviction：超容量时丢最旧的（前面的）。
  final kept = filtered.length > maxShortTermEntries
      ? filtered.sublist(filtered.length - maxShortTermEntries)
      : filtered;

  return AgentMemory(
    index: memory.index,
    shortTerm: kept.join('\n'),
    longTerm: mergedLongTerm,
  );
}
