// crew_gui/lib/services/project_store.dart
import 'dart:convert';
import 'dart:io';
import '../models/project_entry.dart';

class ProjectStore {
  final File file;
  ProjectStore(this.file);

  Future<List<ProjectEntry>> load() async {
    // 用同步 IO：Flutter widget 测试中事件循环被假时钟控制，
    // async IO（await file.exists() 等）不会完成，故用 sync 版本让 Future
    // 经 microtask 完成，pumpAndSettle 才能正常 settle。
    if (!file.existsSync()) return [];
    final list = jsonDecode(file.readAsStringSync()) as List;
    return list
        .map((e) => ProjectEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<ProjectEntry> entries) async {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ')
          .convert(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(ProjectEntry e) async {
    final list = await load();
    list.removeWhere((x) => x.path == e.path);
    list.insert(0, e);
    await save(list);
  }
}
