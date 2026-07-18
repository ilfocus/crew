// crew_gui/test/ui/publish_dialog_test.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart' hide PublishOutcome;
import 'package:crew_gui/app.dart';
import 'package:crew_gui/services/expert_pool_service.dart';
import 'package:crew_gui/ui/publish_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake ExpertPoolService that records calls without touching real IO.
class _FakeExpertPoolService extends ExpertPoolService {
  _FakeExpertPoolService(Directory poolDir)
      : super(AgentPool(poolDir),
            runnerFactory: () => FakeRunner((_, __) => ''));

  PublishOutcome _publishResult = const PublishOutcome(
    agentId: 'fake-id',
    projectId: 'fake-proj',
    domainMerged: 'quant',
  );

  String? lastAgentId;
  String? lastWorkspace;
  String? lastAgent;
  String? lastRetention;
  String? lastSource;
  String? lastDomain;
  int? lastVersion;

  @override
  Future<List<AgentSummary>> list() async => const [];

  @override
  Future<PublishOutcome> publish({
    required String agentId,
    required String workspacePath,
    required String agentName,
    required String retention,
    required String source,
    String? domain,
    required int version,
  }) async {
    lastAgentId = agentId;
    lastWorkspace = workspacePath;
    lastAgent = agentName;
    lastRetention = retention;
    lastSource = source;
    lastDomain = domain;
    lastVersion = version;
    return _publishResult;
  }

  @override
  Future<UseExpertOutcome> useExpert({
    required String agentId,
    required String domain,
    required String intoPath,
    required String agentName,
    required List<String> repos,
  }) async {
    return const UseExpertOutcome(writtenPaths: ['memory/x/MEMORY.md']);
  }
}

/// Host widget that shows a dialog via showDialog from within a Scaffold,
/// so that ScaffoldMessenger.showSnackBar works in tests.
class _DialogHost extends StatefulWidget {
  final WidgetBuilder dialogBuilder;
  const _DialogHost({required this.dialogBuilder});

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(context: context, builder: widget.dialogBuilder);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

void main() {
  late Directory poolDir;
  late _FakeExpertPoolService service;

  setUp(() {
    poolDir = Directory.systemTemp.createTempSync('fake_pool');
    service = _FakeExpertPoolService(poolDir);
  });
  tearDown(() => poolDir.deleteSync(recursive: true));

  Future<void> pumpDialog(
    WidgetTester tester,
    Widget child,
  ) async {
    await tester.pumpWidget(CrewApp(home: _DialogHost(
      dialogBuilder: (_) => child,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('confirm calls publish with correct args and shows success toast',
      (tester) async {
    await pumpDialog(
      tester,
      PublishDialog(
        service: service,
        workspacePath: '/ws/proj',
        agentNames: const ['ios', 'pm'],
      ),
    );

    // Open dropdown and select 'ios'
    await tester.tap(find.text('选择 agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ios').last);
    await tester.pumpAndSettle();

    // Enter agentId
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Agent ID *',
      ),
      'ios-lin',
    );

    // experience-only is the default — no change needed

    // Enter domain
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '领域（可选）',
      ),
      'quant',
    );

    // Tap confirm
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // Assert publish called with correct args
    expect(service.lastAgentId, 'ios-lin');
    expect(service.lastWorkspace, '/ws/proj');
    expect(service.lastAgent, 'ios');
    expect(service.lastRetention, 'experience-only');
    expect(service.lastSource, 'opensource');
    expect(service.lastDomain, 'quant');
    expect(service.lastVersion, 1);

    // Success toast shown
    expect(find.textContaining('已提炼专家'), findsOneWidget);
  });

  testWidgets('retention defaults to experience-only and can switch to full',
      (tester) async {
    await pumpDialog(
      tester,
      PublishDialog(
        service: service,
        workspacePath: '/ws/proj',
        agentNames: const ['ios'],
      ),
    );

    // Select agent
    await tester.tap(find.text('选择 agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ios').last);
    await tester.pumpAndSettle();

    // Enter agentId
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Agent ID *',
      ),
      'ios-lin',
    );

    // Switch to full
    await tester.tap(find.text('完整保留'));
    await tester.pumpAndSettle();

    // Confirm
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(service.lastRetention, 'full');
    expect(service.lastAgentId, 'ios-lin');
  });

  testWidgets('confirm without selecting agent shows error', (tester) async {
    await pumpDialog(
      tester,
      PublishDialog(
        service: service,
        workspacePath: '/ws/proj',
        agentNames: const ['ios'],
      ),
    );

    // Tap confirm without selecting agent
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.text('请选择 agent'), findsOneWidget);
    expect(service.lastAgent, isNull);
  });

  testWidgets('confirm without agentId shows error', (tester) async {
    await pumpDialog(
      tester,
      PublishDialog(
        service: service,
        workspacePath: '/ws/proj',
        agentNames: const ['ios'],
      ),
    );

    // Select agent
    await tester.tap(find.text('选择 agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ios').last);
    await tester.pumpAndSettle();

    // Tap confirm without entering agentId
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.text('请填写 agent id'), findsOneWidget);
    expect(service.lastAgentId, isNull);
  });
}
