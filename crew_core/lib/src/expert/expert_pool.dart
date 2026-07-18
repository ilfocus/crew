// crew_core/lib/src/expert/expert_pool.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../engine/write_planner.dart';
import '../models/expert.dart';
import '../models/expert_summary.dart';
import 'expert_pool_adapter.dart';

/// File-system backed pool of experts.
///
/// Project experts live under `root/projects/<projectId>/` and domain experts
/// under `root/domains/<domain>/`. Each expert directory contains an
/// `expert.json` plus human-readable markdown views produced by
/// [ExpertPoolAdapter].
class ExpertPool {
  final Directory root;
  final ExpertPoolAdapter _adapter;
  final WritePlanner _planner;

  ExpertPool(this.root, {ExpertPoolAdapter? adapter, WritePlanner? planner})
      : _adapter = adapter ?? const ExpertPoolAdapter(),
        _planner = planner ?? WritePlanner();

  /// Writes [e] to `root/projects/<e.meta.projectId>/`.
  ///
  /// Memory files (isMemory: true) that already exist on disk are skipped by
  /// [WritePlanner], preserving user edits across regenerations.
  Future<void> saveProject(Expert e) async {
    final dir = Directory(p.join(root.path, 'projects', e.meta.projectId));
    await _save(dir, e);
  }

  /// Writes [e] to `root/domains/<e.domain>/`.
  Future<void> saveDomain(Expert e) async {
    final dir = Directory(p.join(root.path, 'domains', e.domain));
    await _save(dir, e);
  }

  Future<void> _save(Directory dir, Expert e) async {
    final artifacts = _adapter.render(e);
    final plan = _planner.plan(dir.path, artifacts);
    await _planner.apply(dir.path, plan);
  }

  /// Reads `root/projects/<projectId>/expert.json`. Returns null if absent.
  Future<Expert?> loadProject(String projectId) async {
    final f = File(p.join(root.path, 'projects', projectId, 'expert.json'));
    return _load(f);
  }

  /// Reads `root/domains/<domain>/expert.json`. Returns null if absent.
  Future<Expert?> loadDomain(String domain) async {
    final f = File(p.join(root.path, 'domains', domain, 'expert.json'));
    return _load(f);
  }

  /// Recursively removes `root/projects/<projectId>/`. No-op if absent.
  Future<void> deleteProject(String projectId) async {
    await _delete(p.join(root.path, 'projects', projectId));
  }

  /// Recursively removes `root/domains/<domain>/`. No-op if absent.
  Future<void> deleteDomain(String domain) async {
    await _delete(p.join(root.path, 'domains', domain));
  }

  Future<void> _delete(String path) async {
    final dir = Directory(path);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future<Expert?> _load(File f) async {
    if (!f.existsSync()) return null;
    return _parse(f);
  }

  /// Scans for `expert.json` files under `root/projects/` and
  /// `root/domains/`, returning one [ExpertSummary] per expert found.
  /// The scan is recursive because projectIds (e.g. `github.com/foo/bar`)
  /// contain slashes that map to nested directories. Returns an empty list
  /// if [root] does not exist.
  Future<List<ExpertSummary>> list() async {
    if (!root.existsSync()) return const [];
    final summaries = <ExpertSummary>[];
    await _scanKind(Directory(p.join(root.path, 'projects')),
        (e) => ExpertSummary(
              kind: e.kind,
              id: e.meta.projectId,
              displayName: e.spec.displayName,
              version: e.meta.version,
            ), summaries);
    await _scanKind(Directory(p.join(root.path, 'domains')),
        (e) => ExpertSummary(
              kind: e.kind,
              id: e.domain,
              displayName: e.spec.displayName,
              version: e.meta.version,
            ), summaries);
    return summaries;
  }

  Future<void> _scanKind(
    Directory dir,
    ExpertSummary Function(Expert) toSummary,
    List<ExpertSummary> out,
  ) async {
    if (!dir.existsSync()) return;
    await for (final entry in dir.list(recursive: true)) {
      if (entry is! File) continue;
      if (p.basename(entry.path) != 'expert.json') continue;
      final e = _parse(entry);
      if (e == null) continue;
      out.add(toSummary(e));
    }
  }

  Expert? _parse(File f) {
    try {
      final raw = f.readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Expert.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
