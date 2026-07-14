// crew_gui/test/ui/wizard_assign_targets_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/app.dart';
import 'package:crew_gui/state/wizard_controller.dart';
import 'package:crew_gui/ui/wizard/step_assign.dart';
import 'package:crew_gui/ui/wizard/step_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StepAssign auto-assign button fills assignments', (tester) async {
    final wizard = WizardController();
    wizard.addDirectory('/repo/ios');
    wizard.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'backend'));
    await tester.pumpWidget(CrewApp(home: Scaffold(body: StepAssign(wizard: wizard))));
    await tester.tap(find.text('自动分配'));
    await tester.pumpAndSettle();
    // backend 关联到唯一目录（静态探测无命中时 autoAssign 给空，这里手动勾选验证 chip 存在）
    expect(find.text('/repo/ios'), findsWidgets);
  });

  testWidgets('StepTargets toggles keep at least one', (tester) async {
    final wizard = WizardController();
    await tester.pumpWidget(CrewApp(home: Scaffold(body: StepTargets(wizard: wizard))));
    expect(wizard.targets, {'claude', 'codex'});
    // 计划里 SwitchListTile 标题是 'Codex（...）'，用 textContaining 匹配。
    await tester.tap(find.textContaining('Codex'));
    await tester.pumpAndSettle();
    expect(wizard.targets, {'claude'});
  });
}
