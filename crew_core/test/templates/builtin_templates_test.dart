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

  // --- 新增：探查 prompt 请求能力维度 ---
  test('every probePrompt requests techStack, sdks, difficulties', () {
    for (final t in kBuiltinTemplates) {
      expect(t.probePrompt, contains('techStack'), reason: '${t.id} should request techStack');
      expect(t.probePrompt, contains('sdks'), reason: '${t.id} should request sdks');
      expect(t.probePrompt, contains('difficulties'), reason: '${t.id} should request difficulties');
    }
  });

  // --- 新增：内置模板有人设 ---
  test('every builtin template has non-empty personality and principles', () {
    for (final t in kBuiltinTemplates) {
      expect(t.personality, isNotEmpty, reason: '${t.id} personality');
      expect(t.principles, isNotEmpty, reason: '${t.id} principles');
    }
  });
}
