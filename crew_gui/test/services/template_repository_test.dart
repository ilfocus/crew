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
}
