// crew_gui/lib/services/workspace_opener.dart
import 'dart:io';

abstract class WorkspaceOpener {
  Future<void> openWithTool(String tool, String workspacePath);
  Future<void> openFolder(String workspacePath);
}

class ProcessWorkspaceOpener implements WorkspaceOpener {
  @override
  Future<void> openWithTool(String tool, String workspacePath) async {
    // 在工作空间目录内拉起 CLI（新会话由用户在终端接管；此处仅启动）。
    await Process.start(tool, const [], workingDirectory: workspacePath);
  }

  @override
  Future<void> openFolder(String workspacePath) async {
    if (Platform.isMacOS) {
      await Process.start('open', [workspacePath]);
    } else if (Platform.isWindows) {
      await Process.start('explorer', [workspacePath]);
    } else {
      await Process.start('xdg-open', [workspacePath]);
    }
  }
}

class FakeWorkspaceOpener implements WorkspaceOpener {
  final List<String> calls = [];
  @override
  Future<void> openWithTool(String tool, String workspacePath) async {
    calls.add('openWithTool:$tool:$workspacePath');
  }

  @override
  Future<void> openFolder(String workspacePath) async {
    calls.add('openFolder:$workspacePath');
  }
}
