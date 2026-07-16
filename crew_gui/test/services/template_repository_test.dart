// crew_gui/test/services/template_repository_test.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/services/template_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('tpl'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('all starts with builtins before loading custom', () async {
    final repo = TemplateRepository(File('${dir.path}/custom.json'));
    await repo.loadCustom();
    expect(repo.all.map((t) => t.id), containsAll(kBuiltinTemplates.map((t) => t.id)));
  });

  test('addCustom persists and appears in all + resolve', () async {
    final repo = TemplateRepository(File('${dir.path}/custom.json'));
    await repo.loadCustom();
    const contract = AgentTemplate(
      id: 'solidity', version: 1, defaultName: 'solidity', displayName: '小合',
      role: '智能合约工程师', probePrompt: '探查合约',
      matchGlobs: ['*.sol', 'foundry.toml'],
    );
    await repo.addCustom(contract);

    // 新实例重新加载，验证已落盘
    final repo2 = TemplateRepository(File('${dir.path}/custom.json'));
    await repo2.loadCustom();
    expect(repo2.resolve('solidity@1')?.displayName, '小合');
    expect(repo2.all.any((t) => t.id == 'solidity'), isTrue);
  });

  test('resolve falls back to builtin templateByRef', () async {
    final repo = TemplateRepository(File('${dir.path}/custom.json'));
    await repo.loadCustom();
    expect(repo.resolve('ios-dev@1')?.defaultName, 'ios');
  });

  test('updateCustom overrides builtin by id', () async {
    final repo = TemplateRepository(File('${dir.path}/custom.json'));
    await repo.loadCustom();
    final original = kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev');
    expect(repo.isBuiltin(original), isTrue);

    final edited = AgentTemplate(
      id: 'ios-dev', version: 1, defaultName: 'ios', displayName: '小i改',
      role: '资深 iOS 工程师', probePrompt: '新 prompt',
      matchGlobs: ['*.swift', 'Podfile'],
    );
    await repo.updateCustom(edited);

    // 内置被覆盖
    expect(repo.isBuiltin(original), isFalse);
    final resolved = repo.resolve('ios-dev@1')!;
    expect(resolved.displayName, '小i改');
    expect(resolved.probePrompt, '新 prompt');
  });

  test('removeCustom restores builtin', () async {
    final repo = TemplateRepository(File('${dir.path}/custom.json'));
    await repo.loadCustom();
    final original = kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev');

    await repo.updateCustom(AgentTemplate(
      id: 'ios-dev', version: 1, defaultName: 'ios', displayName: '临时',
      role: 'iOS', probePrompt: 'tmp', matchGlobs: [],
    ));
    expect(repo.isBuiltin(original), isFalse);

    await repo.removeCustom('ios-dev');
    expect(repo.isBuiltin(original), isTrue);
    expect(repo.resolve('ios-dev@1')?.displayName, '小i');
  });

  test('updateCustom persists across instances', () async {
    final file = File('${dir.path}/custom.json');
    final repo = TemplateRepository(file);
    await repo.loadCustom();
    await repo.updateCustom(AgentTemplate(
      id: 'frontend', version: 1, defaultName: 'fe', displayName: '小前改',
      role: '前端', probePrompt: '改了', matchGlobs: ['package.json'],
    ));

    final repo2 = TemplateRepository(file);
    await repo2.loadCustom();
    expect(repo2.resolve('frontend@1')?.displayName, '小前改');
  });

  test('cloneBuiltin returns editable copy', () {
    final repo = TemplateRepository(File('${dir.path}/clone.json'));
    final original = kBuiltinTemplates.firstWhere((t) => t.id == 'backend');
    final clone = repo.cloneBuiltin(original);
    expect(clone.id, original.id);
    expect(clone.probePrompt, original.probePrompt);
    expect(identical(clone, original), isFalse);
  });

  test('personality and principles round-trip through json', () {
    const t = AgentTemplate(
      id: 'rust', version: 1, defaultName: 'rust', displayName: '小R',
      role: 'Rust 工程师', probePrompt: '探查 rust',
      matchGlobs: ['Cargo.toml', '*.rs'],
      personality: '严谨、重性能',
      principles: ['主线程不做 IO', '依赖锁版本'],
    );
    final json = agentTemplateToJson(t);
    final back = agentTemplateFromJson(json);
    expect(back.personality, '严谨、重性能');
    expect(back.principles, ['主线程不做 IO', '依赖锁版本']);
  });

  test('fromJson without personality/principles is backward compatible', () {
    final j = <String, dynamic>{
      'id': 'legacy', 'version': 1, 'defaultName': 'legacy',
      'displayName': '旧', 'role': '旧角色', 'probePrompt': 'p',
      'matchGlobs': <String>['*.txt'],
    };
    final t = agentTemplateFromJson(j);
    expect(t.personality, '');
    expect(t.principles, isEmpty);
  });

  test('cloneBuiltin preserves personality and principles', () {
    final repo = TemplateRepository(File('${dir.path}/clone.json'));
    final original = kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev');
    final clone = repo.cloneBuiltin(original);
    expect(clone.personality, original.personality);
    expect(clone.principles, original.principles);
    // 独立副本，互不影响
    expect(identical(clone.principles, original.principles), isFalse);
  });
}
