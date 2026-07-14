// crew_gui/test/state/wizard_controller_validate_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/state/wizard_controller.dart';
import 'package:crew_gui/state/wizard_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toggleTarget keeps at least one target', () {
    final c = WizardController();
    expect(c.targets, {'claude', 'codex'});
    c.toggleTarget('codex');
    expect(c.targets, {'claude'});
    c.toggleTarget('claude'); // 会清空 -> 被忽略
    expect(c.targets, {'claude'});
  });

  test('canProceed enforces each step', () {
    final c = WizardController();
    expect(c.canProceed(WizardStep.directories), isFalse);
    c.addDirectory('/repo');
    expect(c.canProceed(WizardStep.directories), isTrue);

    expect(c.canProceed(WizardStep.agents), isFalse);
    c.toggleTemplate(kBuiltinTemplates.firstWhere((t) => t.id == 'backend'));
    expect(c.canProceed(WizardStep.agents), isTrue);

    expect(c.canProceed(WizardStep.assign), isFalse); // 未关联
    c.setAssignment('backend', ['/repo']);
    expect(c.canProceed(WizardStep.assign), isTrue);

    expect(c.canProceed(WizardStep.targets), isTrue);

    expect(c.canProceed(WizardStep.preview), isFalse);
    c.setProjectName('apm');
    c.setWorkspaceParent('/ws');
    expect(c.canProceed(WizardStep.preview), isTrue);
  });

  test('buildConfig reflects targets and runner', () {
    final c = WizardController();
    c.toggleTarget('claude'); // 剩 codex
    c.setCliTool('codex');
    final config = c.buildConfig(createdAt: '2026-07-13');
    expect(config.targets, ['codex']);
    expect(config.runner, 'cli');
  });
}
