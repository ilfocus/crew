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
    );

class TemplateRepository {
  final File customFile;
  final List<AgentTemplate> _custom = [];
  TemplateRepository(this.customFile);

  Future<void> loadCustom() async {
    // 同步 IO：与 ProjectStore 同因（widget 测试假时钟下 async IO 不完成）。
    _custom.clear();
    if (!customFile.existsSync()) return;
    final list = jsonDecode(customFile.readAsStringSync()) as List;
    _custom.addAll(
      list.map((e) => agentTemplateFromJson(e as Map<String, dynamic>)),
    );
  }

  List<AgentTemplate> get all => [...kBuiltinTemplates, ..._custom];

  Future<void> addCustom(AgentTemplate t) async {
    _custom.add(t);
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
