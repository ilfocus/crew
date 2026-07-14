// crew_gui/test/ui/wizard_early_steps_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/app.dart';
import 'package:crew_gui/services/directory_picker.dart';
import 'package:crew_gui/state/wizard_controller.dart';
import 'package:crew_gui/ui/wizard/step_agents.dart';
import 'package:crew_gui/ui/wizard/step_directories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StepDirectories adds a picked directory to the list', (tester) async {
    final wizard = WizardController();
    final picker = FakeDirectoryPicker('/repo/ios');
    await tester.pumpWidget(CrewApp(
      home: Scaffold(body: StepDirectories(wizard: wizard, picker: picker)),
    ));
    await tester.tap(find.text('添加目录'));
    await tester.pumpAndSettle();
    expect(find.text('/repo/ios'), findsOneWidget);
    expect(wizard.directories, ['/repo/ios']);
  });

  testWidgets('StepAgents toggles template selection', (tester) async {
    final wizard = WizardController();
    await tester.pumpWidget(CrewApp(
      home: Scaffold(
        body: StepAgents(wizard: wizard, templates: kBuiltinTemplates),
      ),
    ));
    final ios = kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev');
    await tester.tap(find.text(ios.role));
    await tester.pumpAndSettle();
    expect(wizard.isSelected(ios), isTrue);
  });
}
