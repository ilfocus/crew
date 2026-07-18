// crew_gui/test/ui/expert_pool_page_test.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart' hide PublishOutcome;
import 'package:crew_gui/app.dart';
import 'package:crew_gui/services/expert_pool_service.dart';
import 'package:crew_gui/ui/expert_pool_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake ExpertPoolService that returns a pre-seeded list and records calls.
class _FakeExpertPoolService extends ExpertPoolService {
  _FakeExpertPoolService(Directory poolDir)
      : super(AgentPool(poolDir),
            runnerFactory: () => FakeRunner((_, __) => ''));

  List<AgentSummary> seedList = const [];

  String? lastUseAgentId;
  String? lastUseDomain;
  String? lastUseInto;
  String? lastUseAgent;
  List<String>? lastUseRepos;

  String? lastDeleteAgentId;

  int? lastMigrateVersion;
  MigrateOutcome migrateResult = const MigrateOutcome();

  @override
  Future<List<AgentSummary>> list() async => seedList;

  @override
  Future<void> deleteAgent(String agentId) async {
    lastDeleteAgentId = agentId;
  }

  @override
  Future<UseExpertOutcome> useExpert({
    required String agentId,
    required String domain,
    required String intoPath,
    required String agentName,
    required List<String> repos,
  }) async {
    lastUseAgentId = agentId;
    lastUseDomain = domain;
    lastUseInto = intoPath;
    lastUseAgent = agentName;
    lastUseRepos = repos;
    return const UseExpertOutcome(
        writtenPaths: ['memory/x/MEMORY.md', '.crew/specs/x.json']);
  }

  @override
  Future<MigrateOutcome> migrate({required int version}) async {
    lastMigrateVersion = version;
    return migrateResult;
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

  testWidgets('list shows pre-seeded agents with domain chips and project count',
      (tester) async {
    service.seedList = const [
      AgentSummary(
        id: 'ios-lin',
        displayName: 'iOS 工程师',
        version: 1,
        domains: ['mobile', 'quant'],
        projectCount: 3,
      ),
      AgentSummary(
        id: 'pm-zhang',
        displayName: '产品经理老张',
        version: 2,
        domains: [],
        projectCount: 0,
      ),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('iOS 工程师'), findsOneWidget);
    expect(find.text('id: ios-lin · v1'), findsOneWidget);
    // Domain chips
    expect(find.text('mobile'), findsOneWidget);
    expect(find.text('quant'), findsOneWidget);
    // Project count chip
    expect(find.text('3 个项目'), findsOneWidget);
    // Second agent: no chips
    expect(find.text('产品经理老张'), findsOneWidget);
    expect(find.text('id: pm-zhang · v2'), findsOneWidget);
    // Two apply buttons
    expect(find.text('应用到目录'), findsNWidgets(2));
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
      AgentSummary(
        id: 'ios-lin',
        displayName: 'iOS 工程师',
        version: 1,
        domains: ['mobile', 'quant'],
        projectCount: 1,
      ),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    // Click apply
    await tester.tap(find.text('应用到目录'));
    await tester.pumpAndSettle();

    // Open domain dropdown and select 'quant'
    await tester.tap(find.text('领域 *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('quant').last);
    await tester.pumpAndSettle();

    // Fill path, agent name, repos
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '目标目录路径 *',
      ),
      '/tmp/proj',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'agent 名称 *',
      ),
      'ios-agent',
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
    expect(service.lastUseAgentId, 'ios-lin');
    expect(service.lastUseDomain, 'quant');
    expect(service.lastUseInto, '/tmp/proj');
    expect(service.lastUseAgent, 'ios-agent');
    expect(service.lastUseRepos, ['~/repo1', '~/repo2']);

    // Success snackbar
    expect(find.textContaining('已应用'), findsOneWidget);
  });

  testWidgets('apply with missing fields shows error', (tester) async {
    service.seedList = const [
      AgentSummary(
        id: 'ios-lin',
        displayName: 'iOS 工程师',
        version: 1,
        domains: ['mobile'],
        projectCount: 0,
      ),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    // Click apply
    await tester.tap(find.text('应用到目录'));
    await tester.pumpAndSettle();

    // Confirm immediately without filling anything
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.textContaining('请选择领域'), findsOneWidget);
    expect(service.lastUseAgentId, isNull);
  });

  testWidgets('apply with no domains shows snackbar, no dialog', (tester) async {
    service.seedList = const [
      AgentSummary(
        id: 'pm-zhang',
        displayName: '产品经理老张',
        version: 1,
        domains: [],
        projectCount: 0,
      ),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    // Click apply — should show snackbar, not the dialog
    await tester.tap(find.text('应用到目录'));
    await tester.pumpAndSettle();

    expect(find.textContaining('暂无领域专长'), findsOneWidget);
    // Dialog should not be open
    expect(find.text('领域 *'), findsNothing);
  });

  testWidgets('delete agent calls deleteAgent with correct id',
      (tester) async {
    service.seedList = const [
      AgentSummary(
        id: 'ios-lin',
        displayName: 'iOS 工程师',
        version: 1,
        domains: ['mobile'],
        projectCount: 1,
      ),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    // Tap delete on the agent card
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('删除 agent'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(service.lastDeleteAgentId, 'ios-lin');
    expect(find.textContaining('已删除 agent'), findsOneWidget);
  });

  testWidgets('cancel delete does not call service', (tester) async {
    service.seedList = const [
      AgentSummary(
        id: 'ios-lin',
        displayName: 'iOS 工程师',
        version: 1,
        domains: [],
        projectCount: 0,
      ),
    ];

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(service.lastDeleteAgentId, isNull);
  });

  testWidgets('migrate button calls migrate and shows result snackbar',
      (tester) async {
    service.seedList = const [];
    service.migrateResult = const MigrateOutcome(
      agents: 3,
      domainsMoved: 4,
      projectsMoved: 7,
      backupPath: '/tmp/pool.bak',
    );

    await tester.pumpWidget(CrewApp(home: ExpertPoolPage(service: service)));
    await tester.pumpAndSettle();

    // Tap migrate icon
    await tester.tap(find.byTooltip('迁移旧布局'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('迁移池布局'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(service.lastMigrateVersion, 1);
    expect(find.textContaining('已迁移 3 agents'), findsOneWidget);
    expect(find.textContaining('7 projects'), findsOneWidget);
    expect(find.textContaining('备份：/tmp/pool.bak'), findsOneWidget);
  });
}
