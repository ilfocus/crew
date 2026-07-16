// crew_gui/lib/services/template_repository.dart
import 'dart:convert';
import 'dart:io';
import 'package:crew_core/crew_core.dart';

Map<String, dynamic> agentTemplateToJson(AgentTemplate t) => {
      'id': t.id,
      'version': t.version,
      'defaultName': t.defaultName,
      'displayName': t.displayName,
      'role': t.role,
      'probePrompt': t.probePrompt,
      'matchGlobs': t.matchGlobs,
      'personality': t.personality,
      'principles': t.principles,
    };

AgentTemplate agentTemplateFromJson(Map<String, dynamic> j) => AgentTemplate(
      id: j['id'] as String,
      version: j['version'] as int,
      defaultName: j['defaultName'] as String,
      displayName: j['displayName'] as String,
      role: j['role'] as String,
      probePrompt: j['probePrompt'] as String,
      matchGlobs:
          (j['matchGlobs'] as List).map((e) => e.toString()).toList(),
      personality: (j['personality'] as String?) ?? '',
      principles: (j['principles'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );

class TemplateRepository {
  final File customFile;
  final List<AgentTemplate> _custom = [];
  TemplateRepository(this.customFile);

  Future<void> loadCustom() async {
    _custom.clear();
    if (!customFile.existsSync()) return;
    final list = jsonDecode(customFile.readAsStringSync()) as List;
    _custom.addAll(
      list.map((e) => agentTemplateFromJson(e as Map<String, dynamic>)),
    );
  }

  /// 所有模板：自定义覆盖同名内置，其余内置 + 自定义
  List<AgentTemplate> get all {
    final customIds = _custom.map((t) => t.id).toSet();
    return [
      ...kBuiltinTemplates.where((t) => !customIds.contains(t.id)),
      ..._custom,
    ];
  }

  /// 是否为内置模板（未被自定义覆盖）
  bool isBuiltin(AgentTemplate t) =>
      kBuiltinTemplates.any((b) => b.id == t.id && b.ref == t.ref) &&
      !_custom.any((c) => c.id == t.id);

  Future<void> addCustom(AgentTemplate t) async {
    _custom.add(t);
    _persist();
  }

  /// 更新已有自定义模板（按 id+version 匹配）
  Future<void> updateCustom(AgentTemplate t) async {
    final idx = _custom.indexWhere((c) => c.id == t.id && c.version == t.version);
    if (idx >= 0) {
      _custom[idx] = t;
    } else {
      _custom.add(t);
    }
    _persist();
  }

  Future<void> removeCustom(String id) async {
    _custom.removeWhere((c) => c.id == id);
    _persist();
  }

  /// 将内置模板复制为自定义（可编辑的覆盖版本）
  AgentTemplate cloneBuiltin(AgentTemplate t) {
    return AgentTemplate(
      id: t.id,
      version: t.version,
      defaultName: t.defaultName,
      displayName: t.displayName,
      role: t.role,
      probePrompt: t.probePrompt,
      matchGlobs: List.from(t.matchGlobs),
      personality: t.personality,
      principles: List.from(t.principles),
    );
  }

  void _persist() {
    customFile.parent.createSync(recursive: true);
    customFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ')
          .convert(_custom.map(agentTemplateToJson).toList()),
    );
  }

  AgentTemplate? resolve(String ref) {
    for (final t in all) {
      if (t.ref == ref) return t;
    }
    return templateByRef(ref);
  }
}
