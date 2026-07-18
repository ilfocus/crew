// crew_gui/test/ui/expert_pool_page_test.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/app.dart';
import 'package:crew_gui/services/expert_pool_service.dart';
import 'package:crew_gui/ui/expert_pool_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake ExpertPoolService that returns a pre-seeded list and records calls.
class _FakeExpertPoolService extends ExpertPoolService {
  _FakeExpertPoolService(Directory poolDir)
      : super(ExpertPool(poolDir),
            runnerFactory: () => FakeRunner((_, __) => ''));

  List<ExpertSummary> seedList = const [];

  String? lastUseDomain;
  String? lastUseInto;
  String? lastUseAgent;
  List<String>? lastUseRepos;

  String? lastDeleteProjectId;
  String? lastDeleteDomain;

  @override
  Future<List<ExpertSummary>> list() async => seedList;

  @override
  Future<void> deleteProject(String projectId) async {
    lastDeleteProjectId = projectId;
  }

  @override
  Future<void> deleteDomain(String domain) async {
    lastDeleteDomain = domain;
  }

  @override
  Future<PublishOutcome> publish({
    required String workspacePath,
    required String agentName,
    required String retention,
    required String source,
    String? domain,
    required int version,
  }) async {
    return const PublishOutcome(projectId: 'fake-id');
  }

  @override
  Future<UseExpertOutcome> useExpert({
    required String domain,
    required String intoPath,
    required String agentName,
    required List<String> repos,
  }) async {
    lastUseDomain = domain;
    lastUseInto = intoPath;
    lastUseAgent = agentName;
    lastUseRepos = repos;
    return const UseExpertOutcome(
        writtenPaths: ['memory/x/MEMORY.md', '.crew/specs/x.json']);
  }
}

void main() {
  late Directory poolDir;
  late _FakeExpertPoolService service;

  setUp(() {
    poolDir = Directory.systemTemp.createTempSync('fake_pool');
    service = _FakeExpertPoolService(poolDir);
  });
  tearDown(() => poolDir.deleteSync(recursive: true));

  testWidgets('list shows pre-seeded domain + project experts', (tester) async {
    service.seedList = const [
      ExpertSummary(
          kind: ExpertKind.domain,
          id: 'quant',
          displayName: '量化领域专家',
          version: 1),
      ExpertSummary(
          kind: ExpertKind.project,
          id: 'github.com/foo/bar',
          displayName: '小i',
          version: 2),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('领域专家'), findsOneWidget);
    expect(find.text('量化领域专家'), findsOneWidget);
    expect(find.text('项目专家'), findsOneWidget);
    expect(find.text('小i'), findsOneWidget);
    // Domain has apply button
    expect(find.text('应用到目录'), findsOneWidget);
  });

  testWidgets('empty pool shows guidance', (tester) async {
    service.seedList = const [];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    expect(find.textContaining('专家池为空'), findsOneWidget);
  });

  testWidgets('apply to directory calls useExpert with correct args',
      (tester) async {
    service.seedList = const [
      ExpertSummary(
          kind: ExpertKind.domain,
          id: 'quant',
          displayName: '量化领域专家',
          version: 1),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    // Click apply
    await tester.tap(find.text('应用到目录'));
    await tester.pumpAndSettle();

    // Fill path, agent name, repos
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '目标目录路径',
      ),
      '/tmp/proj',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'agent 名称',
      ),
      'quant-agent',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '仓库（逗号分隔）',
      ),
      '~/repo1, ~/repo2',
    );

    // Confirm
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // Assert useExpert called with correct args
    expect(service.lastUseDomain, 'quant');
    expect(service.lastUseInto, '/tmp/proj');
    expect(service.lastUseAgent, 'quant-agent');
    expect(service.lastUseRepos, ['~/repo1', '~/repo2']);

    // Success snackbar
    expect(find.textContaining('已应用'), findsOneWidget);
  });

  testWidgets('delete domain calls deleteDomain with correct id',
      (tester) async {
    service.seedList = const [
      ExpertSummary(
          kind: ExpertKind.domain,
          id: 'quant',
          displayName: '量化领域专家',
          version: 1),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    // Tap delete on the domain card
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('删除领域专家'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(service.lastDeleteDomain, 'quant');
    expect(find.textContaining('已删除'), findsOneWidget);
  });

  testWidgets('delete project expert calls deleteProject with correct id',
      (tester) async {
    service.seedList = const [
      ExpertSummary(
          kind: ExpertKind.project,
          id: 'github.com/foo/bar',
          displayName: '小i',
          version: 2),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除项目专家'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(service.lastDeleteProjectId, 'github.com/foo/bar');
  });

  testWidgets('cancel delete does not call service', (tester) async {
    service.seedList = const [
      ExpertSummary(
          kind: ExpertKind.domain,
          id: 'quant',
          displayName: '量化领域专家',
          version: 1),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(service.lastDeleteDomain, isNull);
  });
}
