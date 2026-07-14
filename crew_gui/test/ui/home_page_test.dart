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
}
