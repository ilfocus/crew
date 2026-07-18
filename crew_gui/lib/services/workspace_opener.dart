// crew_gui/lib/services/workspace_opener.dart
import 'dart:io';

abstract class WorkspaceOpener {
  Future<void> openWithTool(String tool, String workspacePath);
  Future<void> openFolder(String workspacePath);
}

class ProcessWorkspaceOpener implements WorkspaceOpener {
  @override
  Future<void> openWithTool(String tool, String workspacePath) async {
    if (Platform.isMacOS) {
      // 用 osascript 让 Terminal.app 开新窗口并执行 tool。
      // 直接 Process.start 拉起 CLI 会因无 TTY 导致 TUI 程序（如 claude）看不到任何输出。
      final escapedPath = workspacePath.replaceAll("'", "'\\''");
      final shellCmd = "cd '$escapedPath' && $tool; exec \$SHELL";
      // AppleScript 字符串里转义双引号和反斜杠
      final applesafe =
          shellCmd.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      await Process.start(
        'osascript',
        ['-e', 'tell application "Terminal" to do script "$applesafe"'],
      );
      // 把 Terminal 拉到前台
      await Process.start('open', ['-a', 'Terminal']);
      return;
    }
    if (Platform.isWindows) {
      // start cmd /k "cd /d PATH && tool"——避免嵌套双引号
      await Process.start(
        'cmd',
        ['/c', 'start', 'cmd', '/k', 'cd /d $workspacePath && $tool'],
      );
      return;
    }
    // Linux: 尝试 x-terminal-emulator（Debian 系默认软链）或常见终端
    final escapedPath = workspacePath.replaceAll("'", "'\\''");
    final shellCmd = "cd '$escapedPath' && $tool; exec \$SHELL";
    try {
      await Process.start(
        'x-terminal-emulator',
        ['-e', 'bash', '-c', shellCmd],
      );
    } on ProcessException {
      // 退而求其次：直接启动 CLI（无 TTY，至少不阻塞）
      await Process.start(tool, const [], workingDirectory: workspacePath);
    }
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
