// crew_core/test/expert/memory_eviction_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

AgentMemory _memory({
  String shortTerm = '',
  List<MemoryEntry> longTerm = const [],
  String index = '# MEMORY',
}) {
  return AgentMemory(
    index: index,
    shortTerm: shortTerm,
    longTerm: longTerm,
  );
}

void main() {
  group('consolidate — promote to long-term', () {
    test('promoted entries are added to longTerm', () {
      final m = _memory(shortTerm: 'line A\nline B');
      final out = consolidate(
        memory: m,
        promoteToLongTerm: [
          MemoryEntry('long-term/insight-1.md', 'A 的抽象'),
        ],
        dropFromShortTerm: const [],
      );
      expect(out.longTerm.length, 1);
      expect(out.longTerm.first.path, 'long-term/insight-1.md');
      expect(out.longTerm.first.content, 'A 的抽象');
    });

    test('promoted entries dedup by path (existing not overwritten)', () {
      final m = _memory(longTerm: [
        MemoryEntry('long-term/x.md', 'old'),
      ]);
      final out = consolidate(
        memory: m,
        promoteToLongTerm: [
          MemoryEntry('long-term/x.md', 'new (should not overwrite)'),
          MemoryEntry('long-term/y.md', 'new entry'),
        ],
        dropFromShortTerm: const [],
      );
      expect(out.longTerm.length, 2);
      final x = out.longTerm.firstWhere((e) => e.path == 'long-term/x.md');
      expect(x.content, 'old'); // 已存在不覆盖
      final y = out.longTerm.firstWhere((e) => e.path == 'long-term/y.md');
      expect(y.content, 'new entry');
    });

    test('multiple promotes all added (different paths)', () {
      final m = _memory();
      final out = consolidate(
        memory: m,
        promoteToLongTerm: [
          MemoryEntry('long-term/a.md', 'A'),
          MemoryEntry('long-term/b.md', 'B'),
          MemoryEntry('long-term/c.md', 'C'),
        ],
        dropFromShortTerm: const [],
      );
      expect(out.longTerm.length, 3);
    });
  });

  group('consolidate — drop from short-term', () {
    test('drop matching lines from shortTerm', () {
      final m = _memory(shortTerm: 'keep A\ndrop me\nkeep B\ndrop me too');
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: ['drop me', 'drop me too'],
      );
      final lines = out.shortTerm.split('\n');
      expect(lines, contains('keep A'));
      expect(lines, contains('keep B'));
      expect(lines.any((l) => l.contains('drop')), isFalse);
    });

    test('drop with no match leaves shortTerm unchanged', () {
      final m = _memory(shortTerm: 'a\nb\nc');
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: ['not-in-list'],
      );
      expect(out.shortTerm, 'a\nb\nc');
    });

    test('empty shortTerm + drop leaves empty', () {
      final m = _memory(shortTerm: '');
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: ['x'],
      );
      // split('') on empty string yields [''], filter to [] leaves []
      expect(out.shortTerm, '');
    });
  });

  group('consolidate — FIFO eviction', () {
    test('shortTerm over capacity: oldest lines dropped (FIFO)', () {
      // 60 行短期，阈值 50 → 前 10 行被丢弃
      final lines = [for (var i = 0; i < 60; i++) 'line-$i'];
      final m = _memory(shortTerm: lines.join('\n'));
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: const [],
        maxShortTermEntries: 50,
      );
      final remaining = out.shortTerm.split('\n');
      expect(remaining.length, 50);
      // 最旧的 10 行（line-0..line-9）应被丢弃
      expect(remaining.first, 'line-10');
      expect(remaining.last, 'line-59');
    });

    test('shortTerm under capacity: no eviction', () {
      final m = _memory(shortTerm: 'a\nb\nc');
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: const [],
        maxShortTermEntries: 50,
      );
      expect(out.shortTerm, 'a\nb\nc');
    });

    test('FIFO applies after drop', () {
      // 55 行，drop 5 行后剩 50 → 不需 FIFO
      final lines = [for (var i = 0; i < 55; i++) 'line-$i'];
      final m = _memory(shortTerm: lines.join('\n'));
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: ['line-0', 'line-1', 'line-2', 'line-3', 'line-4'],
        maxShortTermEntries: 50,
      );
      final remaining = out.shortTerm.split('\n');
      expect(remaining.length, 50);
      expect(remaining.first, 'line-5');
      expect(remaining.last, 'line-54');
    });

    test('FIFO applies after drop when still over capacity', () {
      // 60 行，drop 5 行后剩 55 → 仍超 50，FIFO 再丢 5 行
      final lines = [for (var i = 0; i < 60; i++) 'line-$i'];
      final m = _memory(shortTerm: lines.join('\n'));
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: ['line-0', 'line-1', 'line-2', 'line-3', 'line-4'],
        maxShortTermEntries: 50,
      );
      final remaining = out.shortTerm.split('\n');
      expect(remaining.length, 50);
      // drop 了 line-0..4，剩 line-5..59（55 条），FIFO 再丢前 5 → line-10..59
      expect(remaining.first, 'line-10');
      expect(remaining.last, 'line-59');
    });

    test('custom maxShortTermEntries = 0 drops all', () {
      final m = _memory(shortTerm: 'a\nb\nc');
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: const [],
        maxShortTermEntries: 0,
      );
      expect(out.shortTerm, '');
    });
  });

  group('consolidate — long-term protection', () {
    test('long-term entries never deleted (even with FIFO overflow)', () {
      final m = _memory(
        shortTerm: [for (var i = 0; i < 60; i++) 'line-$i'].join('\n'),
        longTerm: [
          MemoryEntry('long-term/a.md', 'A'),
          MemoryEntry('long-term/b.md', 'B'),
          MemoryEntry('long-term/c.md', 'C'),
        ],
      );
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: const [],
        maxShortTermEntries: 50,
      );
      // FIFO 只影响 shortTerm，longTerm 保持原样
      expect(out.longTerm.length, 3);
      expect(out.longTerm.map((e) => e.path).toSet(),
          {'long-term/a.md', 'long-term/b.md', 'long-term/c.md'});
    });

    test('long-term dedup also preserves existing entries', () {
      final m = _memory(longTerm: [
        MemoryEntry('long-term/a.md', 'old A'),
        MemoryEntry('long-term/a.md', 'duplicate (should be dropped)'),
        MemoryEntry('long-term/b.md', 'B'),
      ]);
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: const [],
      );
      // 输入侧的重复也按 path 去重，保留首次出现的
      expect(out.longTerm.length, 2);
      final a = out.longTerm.firstWhere((e) => e.path == 'long-term/a.md');
      expect(a.content, 'old A');
    });
  });

  group('consolidate — index preserved', () {
    test('index is preserved from input memory', () {
      final m = AgentMemory(
        index: '# MY INDEX',
        shortTerm: 'x',
        longTerm: const [],
      );
      final out = consolidate(
        memory: m,
        promoteToLongTerm: const [],
        dropFromShortTerm: const [],
      );
      expect(out.index, '# MY INDEX');
    });
  });

  group('consolidate — combined flow', () {
    test('promote + drop + FIFO in one call', () {
      final lines = [for (var i = 0; i < 55; i++) 'line-$i'];
      final m = _memory(
        shortTerm: lines.join('\n'),
        longTerm: [MemoryEntry('long-term/old.md', 'old')],
      );
      final out = consolidate(
        memory: m,
        promoteToLongTerm: [
          MemoryEntry('long-term/old.md', 'should not overwrite'),
          MemoryEntry('long-term/new.md', 'new insight'),
        ],
        dropFromShortTerm: ['line-0', 'line-1'],
        maxShortTermEntries: 50,
      );
      // longTerm: old 保留 + new 新增 = 2
      expect(out.longTerm.length, 2);
      expect(out.longTerm.firstWhere((e) => e.path == 'long-term/old.md').content,
          'old');
      expect(out.longTerm.firstWhere((e) => e.path == 'long-term/new.md').content,
          'new insight');
      // shortTerm: drop 2 → 53 条，FIFO 再丢 3 → 50 条
      final remaining = out.shortTerm.split('\n');
      expect(remaining.length, 50);
      expect(remaining.first, 'line-5');
      expect(remaining.last, 'line-54');
    });
  });
}
