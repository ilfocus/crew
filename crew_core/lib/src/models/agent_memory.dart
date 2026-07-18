// crew_core/lib/src/models/agent_memory.dart
import 'expert.dart' show MemoryEntry;

/// Agent 本体记忆（跨项目），spec §4.1 / §4.4。
///
/// 切分短期 / 长期：
/// - `shortTerm`：近期上下文，可滚动淘汰（FIFO + 收工归并）。
/// - `longTerm`：沉淀下来的语义/情景/程序记忆，每条一文件；**长期只增不自动删**。
class AgentMemory {
  /// `MEMORY.md`：召回索引。
  final String index;

  /// `short-term.md`：短期记忆（一行一条），可淘汰。
  final String shortTerm;

  /// `long-term/<path>`：长期记忆（每条一文件）。
  final List<MemoryEntry> longTerm;

  const AgentMemory({
    this.index = '',
    this.shortTerm = '',
    this.longTerm = const [],
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'shortTerm': shortTerm,
        'longTerm': longTerm.map((e) => e.toJson()).toList(),
      };

  factory AgentMemory.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(
      dynamic v,
      T Function(Map<String, dynamic>) fromJson,
    ) =>
        ((v as List?) ?? const [])
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList();
    return AgentMemory(
      index: j['index']?.toString() ?? '',
      shortTerm: j['shortTerm']?.toString() ?? '',
      longTerm: list(j['longTerm'], MemoryEntry.fromJson),
    );
  }
}
