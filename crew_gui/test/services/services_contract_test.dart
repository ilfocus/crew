// crew_gui/test/services/services_contract_test.dart
import 'package:crew_gui/services/directory_picker.dart';
import 'package:crew_gui/services/workspace_opener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FakeDirectoryPicker returns configured path', () async {
    final picker = FakeDirectoryPicker('/repo/ios');
    expect(await picker.pick(), '/repo/ios');
    picker.next = null;
    expect(await picker.pick(), isNull);
  });

  test('FakeWorkspaceOpener records calls', () async {
    final opener = FakeWorkspaceOpener();
    await opener.openWithTool('claude', '/ws/apm');
    await opener.openFolder('/ws/apm');
    expect(opener.calls, ['openWithTool:claude:/ws/apm', 'openFolder:/ws/apm']);
  });
}
