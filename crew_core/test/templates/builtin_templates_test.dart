// crew_core/test/templates/builtin_templates_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  test('builtin library contains the initial six roles', () {
    final ids = kBuiltinTemplates.map((t) => t.id).toSet();
    expect(ids, containsAll(<String>{
      'ios-dev', 'android-dev', 'frontend', 'backend', 'python', 'pm',
    }));
  });

  test('templateByRef resolves ref and returns null when absent', () {
    expect(templateByRef('ios-dev@1')?.defaultName, 'ios');
    expect(templateByRef('does-not-exist@9'), isNull);
  });

  test('every template has a non-empty probePrompt', () {
    for (final t in kBuiltinTemplates) {
      expect(t.probePrompt.trim(), isNotEmpty, reason: t.id);
    }
  });
}
