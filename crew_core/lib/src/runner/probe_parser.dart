// crew_core/lib/src/runner/probe_parser.dart
import 'dart:convert';
import '../models/agent_spec.dart';

/// 从 rawOutput 中抽取第一个平衡花括号的 JSON 对象并解析为 AgentSpec。
AgentSpec parseProbe(
  String rawOutput, {
  required String name,
  required String displayName,
  required List<String> repos,
}) {
  final jsonText = extractFirstJsonObject(rawOutput);
  if (jsonText == null) {
    throw FormatException('probe 输出中未找到 JSON 对象', rawOutput);
  }
  final map = jsonDecode(jsonText) as Map<String, dynamic>;
  return AgentSpec.fromProbeJson(
    map,
    name: name,
    displayName: displayName,
    repos: repos,
  );
}

/// 从原始字符串中抽取第一个平衡花括号的 JSON 对象文本。
/// 找不到时返回 null。可处理被散文 / ```json 包裹的输出。
String? extractFirstJsonObject(String s) {
  final start = s.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < s.length; i++) {
    final c = s[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return s.substring(start, i + 1);
    }
  }
  return null;
}
