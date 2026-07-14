import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/file_artifact.dart';

enum WriteAction { create, overwrite, writeNew, skip }

class PlannedWrite {
  final FileArtifact artifact;
  final WriteAction action;
  final String targetPath; // relative
  const PlannedWrite(this.artifact, this.action, this.targetPath);
}

class WritePlan {
  final List<PlannedWrite> writes;
  const WritePlan(this.writes);
}

String _hash(String s) {
  // FNV-1a 32-bit，稳定、无外部依赖。
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}

class WritePlanner {
  Map<String, String> _readManifest(String root) {
    final f = File(p.join(root, '.crew', 'manifest.json'));
    if (!f.existsSync()) return {};
    final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, v.toString()));
  }

  WritePlan plan(String root, List<FileArtifact> artifacts) {
    final manifest = _readManifest(root);
    final writes = <PlannedWrite>[];
    for (final a in artifacts) {
      final abs = File(p.join(root, a.relativePath));
      final exists = abs.existsSync();
      WriteAction action;
      if (!exists) {
        action = WriteAction.create;
      } else if (a.isMemory) {
        action = WriteAction.skip;
      } else {
        final current = abs.readAsStringSync();
        final recorded = manifest[a.relativePath];
        if (recorded != null && recorded == _hash(current)) {
          action = WriteAction.overwrite;
        } else {
          action = WriteAction.writeNew;
        }
      }
      final target = action == WriteAction.writeNew
          ? '${a.relativePath}.new'
          : a.relativePath;
      writes.add(PlannedWrite(a, action, target));
    }
    return WritePlan(writes);
  }

  Future<void> apply(String root, WritePlan plan) async {
    final manifest = _readManifest(root);
    for (final w in plan.writes) {
      if (w.action == WriteAction.skip) continue;
      final abs = File(p.join(root, w.targetPath));
      abs.parent.createSync(recursive: true);
      abs.writeAsStringSync(w.artifact.content);
      if (w.action == WriteAction.create || w.action == WriteAction.overwrite) {
        manifest[w.artifact.relativePath] = _hash(w.artifact.content);
      }
    }
    final mf = File(p.join(root, '.crew', 'manifest.json'));
    mf.parent.createSync(recursive: true);
    mf.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(manifest));
  }
}
