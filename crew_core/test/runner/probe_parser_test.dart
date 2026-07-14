// crew_core/test/runner/probe_parser_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  test('parses raw json', () {
    final spec = parseProbe(
      '{"role":"iOS 开发","conventions":["a"]}',
      name: 'ios', displayName: '小i', repos: ['~/x'],
    );
    expect(spec.role, 'iOS 开发');
    expect(spec.conventions, ['a']);
  });

  test('parses json wrapped in a fenced code block with prose around it', () {
    const raw = '好的，结果如下：\n```json\n{"role":"后端"}\n```\n完成。';
    final spec = parseProbe(raw, name: 'be', displayName: '小后', repos: []);
    expect(spec.role, '后端');
  });

  test('throws when no json object present', () {
    expect(
      () => parseProbe('no json here', name: 'x', displayName: 'y', repos: []),
      throwsA(isA<FormatException>()),
    );
  });
}
