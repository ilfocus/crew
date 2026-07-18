// crew_gui/test/services/project_store_test.dart
import 'dart:io';
import 'package:crew_gui/models/project_entry.dart';
import 'package:crew_gui/services/project_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late ProjectStore store;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('projstore');
    store = ProjectStore(File('${dir.path}/projects.json'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('empty when file absent', () async {
    expect(await store.load(), isEmpty);
  });

  test('add persists and dedupes by path (newest first)', () async {
    await store.add(const ProjectEntry(
      name: 'apm', path: '/ws/apm', createdAt: '2026-07-13',
      repoCount: 2, agentCount: 3));
    await store.add(const ProjectEntry(
      name: 'web', path: '/ws/web', createdAt: '2026-07-13',
      repoCount: 1, agentCount: 1));
    await store.add(const ProjectEntry(
      name: 'apm2', path: '/ws/apm', createdAt: '2026-07-14',
      repoCount: 4, agentCount: 5)); // same path -> overwrite + 置顶

    final list = await store.load();
    expect(list.length, 2);
    expect(list.first.path, '/ws/apm');
    expect(list.first.name, 'apm2');
  });

  test('remove deletes entry by path', () async {
    await store.add(const ProjectEntry(
      name: 'apm', path: '/ws/apm', createdAt: '2026-07-13',
      repoCount: 2, agentCount: 3));
    await store.add(const ProjectEntry(
      name: 'web', path: '/ws/web', createdAt: '2026-07-13',
      repoCount: 1, agentCount: 1));

    await store.remove('/ws/apm');

    final list = await store.load();
    expect(list.length, 1);
    expect(list.first.path, '/ws/web');
  });

  test('remove is a no-op when path absent', () async {
    await store.add(const ProjectEntry(
      name: 'apm', path: '/ws/apm', createdAt: '2026-07-13',
      repoCount: 2, agentCount: 3));

    await store.remove('/ws/not-there');

    final list = await store.load();
    expect(list.length, 1);
    expect(list.first.path, '/ws/apm');
  });
}
