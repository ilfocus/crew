// crew_core/test/runner/distill_parser_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  group('parseDistill', () {
    test('parses valid output with notes and playbooks', () {
      const raw = '{"domainNotes":"iOS 领域共性","playbooks":'
          '[{"path":"排查-内存泄漏.md","content":"1. Instruments 2. 看堆"}]}';
      final r = parseDistill(raw);
      expect(r.domainNotes, 'iOS 领域共性');
      expect(r.playbooks.length, 1);
      expect(r.playbooks.first.path, '排查-内存泄漏.md');
      expect(r.playbooks.first.content, '1. Instruments 2. 看堆');
    });

    test('parses output wrapped in prose / fenced code block', () {
      const raw = '好的，抽象结果如下：\n```json\n'
          '{"domainNotes":"抽象笔记","playbooks":[]}\n```\n完成。';
      final r = parseDistill(raw);
      expect(r.domainNotes, '抽象笔记');
      expect(r.playbooks, isEmpty);
    });

    test('throws FormatException when no JSON object present', () {
      expect(
        () => parseDistill('这里没有任何 JSON'),
        throwsA(isA<FormatException>()),
      );
    });

    test('empty playbooks list works', () {
      const raw = '{"domainNotes":"只有笔记","playbooks":[]}';
      final r = parseDistill(raw);
      expect(r.domainNotes, '只有笔记');
      expect(r.playbooks, isEmpty);
    });

    test('tolerates missing domainNotes (defaults to empty)', () {
      const raw = '{"playbooks":[{"path":"a.md","content":"x"}]}';
      final r = parseDistill(raw);
      expect(r.domainNotes, '');
      expect(r.playbooks.length, 1);
      expect(r.playbooks.first.path, 'a.md');
    });

    test('tolerates missing playbooks (defaults to empty list)', () {
      const raw = '{"domainNotes":"n"}';
      final r = parseDistill(raw);
      expect(r.domainNotes, 'n');
      expect(r.playbooks, isEmpty);
    });
  });
}
