// crew_core/lib/src/expert/redact.dart

/// 把文本里的路径类 token 替换为占位符 '‹path›'，用于跨项目发布前脱敏。
///
/// 覆盖：
/// - 绝对 unix 路径：/Users/...、/home/...、/opt/... 等以 / 开头的路径段
/// - home 路径：~/...
/// - windows 路径：C:\...
/// - 带行号的文件引用：foo/bar.dart:123、Core/BMApm.swift:279
///
/// URL（https://...、http://...、git@...）不受影响。
String redactPaths(String input) {
  // 先保护 URL，用唯一占位符替换，脱敏后恢复
  final urls = <String>[];
  var result = input;

  // 匹配 URL：https://...、http://...、git@host:owner/repo
  final urlPattern = RegExp(r'https?://[^\s<>|*"]+|git@[^\s<>|*"]+');
  result = result.replaceAllMapped(urlPattern, (m) {
    urls.add(m.group(0)!);
    return '\x00URL${urls.length - 1}\x00';
  });

  // 1. Windows 路径：C:\... 或 D:\...
  result = result.replaceAll(RegExp(r'[A-Za-z]:\\[^\s|*]+'), '‹path›');

  // 2. Unix home 路径：~/...
  result = result.replaceAll(RegExp(r'~/[^\s|*]+'), '‹path›');

  // 3. 绝对 unix 路径：/Users/...、/home/...、/opt/...
  result = result.replaceAll(RegExp(r'/(?:[^\s/|*][^\s|*]*)+'), '‹path›');

  // 4. 带行号的相对文件引用：foo/bar.dart:123、Core/BMApm.swift:279
  result = result.replaceAll(RegExp(r'[\w./-]+/[\w./-]+:\d+'), '‹path›');

  // 恢复 URL
  for (var i = 0; i < urls.length; i++) {
    result = result.replaceFirst('\x00URL$i\x00', urls[i]);
  }

  return result;
}
