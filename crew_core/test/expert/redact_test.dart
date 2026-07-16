// crew_core/test/expert/redact_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  group('redactPaths', () {
    test('replaces absolute unix paths', () {
      final r = redactPaths('关联目录：/Users/bm/app/ios');
      expect(r.contains('/Users/bm/app/ios'), isFalse);
      expect(r.contains('‹path›'), isTrue);
    });

    test('replaces home paths', () {
      final r = redactPaths('工作在 ~/bm_app/ios 下');
      expect(r.contains('~/bm_app/ios'), isFalse);
      expect(r.contains('‹path›'), isTrue);
    });

    test('replaces windows paths', () {
      final r = redactPaths('代码在 C:\\proj\\x 里');
      expect(r.contains('C:\\proj\\x'), isFalse);
      expect(r.contains('‹path›'), isTrue);
    });

    test('replaces file:line references', () {
      final r = redactPaths('问题出在 Core/BMApm.swift:279');
      expect(r.contains('Core/BMApm.swift:279'), isFalse);
      expect(r.contains('‹path›'), isTrue);
    });

    test('replaces relative path with line number', () {
      final r = redactPaths('修复了 foo/bar.dart:123 的崩溃');
      expect(r.contains('foo/bar.dart:123'), isFalse);
      expect(r.contains('‹path›'), isTrue);
    });

    test('preserves plain text without paths', () {
      expect(redactPaths('这是一段普通文本，没有路径'), '这是一段普通文本，没有路径');
    });

    test('preserves URLs', () {
      final r = redactPaths('参见 https://github.com/foo/bar 了解更多');
      expect(r.contains('https://github.com/foo/bar'), isTrue);
      expect(r.contains('‹path›'), isFalse);
    });

    test('preserves URLs with paths after //', () {
      final r = redactPaths('仓库地址: https://github.com/foo/bar.git');
      expect(r.contains('https://github.com/foo/bar.git'), isTrue);
    });

    test('handles multiple paths in one string', () {
      final r = redactPaths('源码在 /Users/a/src，配置在 ~/config，日志在 D:\\logs');
      expect(r.contains('/Users/a/src'), isFalse);
      expect(r.contains('~/config'), isFalse);
      expect(r.contains('D:\\logs'), isFalse);
      expect('‹path›'.allMatches(r).length, 3);
    });

    test('handles file:line without directory separator (no match)', () {
      // file:123 without a / should not be matched (could be a label)
      final r = redactPaths('参见 README:123');
      expect(r, '参见 README:123');
    });
  });
}
