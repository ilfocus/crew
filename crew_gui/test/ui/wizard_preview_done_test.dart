// crew_gui/test/ui/wizard_preview_done_test.dart
import 'package:crew_gui/app.dart';
import 'package:crew_gui/services/workspace_opener.dart';
import 'package:crew_gui/ui/wizard/step_done.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StepDone open-with-tool calls opener', (tester) async {
    final opener = FakeWorkspaceOpener();
    await tester.pumpWidget(CrewApp(
      home: Scaffold(
        body: StepDone(
          workspacePath: '/ws/apm',
          opener: opener,
          cliTool: 'claude',
          onFinish: () {},
        ),
      ),
    ));
    await tester.tap(find.textContaining('用 claude 打开'));
    await tester.pumpAndSettle();
    expect(opener.calls, contains('openWithTool:claude:/ws/apm'));
  });
}
