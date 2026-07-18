// crew_gui/test/ui/home_page_test.dart
import 'dart:io';
import 'package:crew_gui/app.dart';
import 'package:crew_gui/models/project_entry.dart';
import 'package:crew_gui/services/project_store.dart';
import 'package:crew_gui/ui/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty state shows guidance and FAB triggers onNew', (tester) async {
    final dir = Directory.systemTemp.createTempSync('home');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = ProjectStore(File('${dir.path}/p.json'));
    var newTapped = 0;

    await tester.pumpWidget(CrewApp(
      home: HomePage(store: store, onNew: () => newTapped++, onOpen: (_) {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('新建'), findsWidgets);
    await tester.tap(find.byType(FloatingActionButton));
    expect(newTapped, 1);
  });

  testWidgets('lists persisted projects', (tester) async {
    final dir = Directory.systemTemp.createTempSync('home2');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = ProjectStore(File('${dir.path}/p.json'));
    await store.add(const ProjectEntry(
      name: 'apm', path: '/ws/apm', createdAt: '2026-07-13',
      repoCount: 2, agentCount: 3));

    await tester.pumpWidget(CrewApp(
      home: HomePage(store: store, onNew: () {}, onOpen: (_) {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text('apm'), findsOneWidget);
  });

  testWidgets('delete project removes it from list after confirm',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('home3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = ProjectStore(File('${dir.path}/p.json'));
    await store.add(const ProjectEntry(
      name: 'apm', path: '/ws/apm', createdAt: '2026-07-13',
      repoCount: 2, agentCount: 3));
    await store.add(const ProjectEntry(
      name: 'web', path: '/ws/web', createdAt: '2026-07-13',
      repoCount: 1, agentCount: 1));

    await tester.pumpWidget(CrewApp(
      home: HomePage(store: store, onNew: () {}, onOpen: (_) {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('apm'), findsOneWidget);
    expect(find.text('web'), findsOneWidget);

    // 找到 apm 卡片上的删除按钮（列表中 apm 不是第一项）
    final apmCard = find
        .ancestor(of: find.text('apm'), matching: find.byType(Card));
    final apmDelete =
        find.descendant(of: apmCard, matching: find.byTooltip('删除'));
    await tester.tap(apmDelete);
    await tester.pumpAndSettle();

    expect(find.text('删除项目'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    // apm removed, web still present
    expect(find.text('apm'), findsNothing);
    expect(find.text('web'), findsOneWidget);

    // persisted
    final persisted = await store.load();
    expect(persisted.length, 1);
    expect(persisted.first.name, 'web');
  });

  testWidgets('cancel delete keeps project in list', (tester) async {
    final dir = Directory.systemTemp.createTempSync('home4');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = ProjectStore(File('${dir.path}/p.json'));
    await store.add(const ProjectEntry(
      name: 'apm', path: '/ws/apm', createdAt: '2026-07-13',
      repoCount: 2, agentCount: 3));

    await tester.pumpWidget(CrewApp(
      home: HomePage(store: store, onNew: () {}, onOpen: (_) {}),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('apm'), findsOneWidget);
    expect((await store.load()).length, 1);
  });
}
