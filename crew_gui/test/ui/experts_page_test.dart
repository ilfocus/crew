// crew_gui/test/ui/experts_page_test.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/app.dart';
import 'package:crew_gui/services/template_repository.dart';
import 'package:crew_gui/ui/experts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('experts'));
  tearDown(() => dir.deleteSync(recursive: true));

  TemplateRepository _newRepo() {
    final repo = TemplateRepository(File('${dir.path}/custom.json'));
    repo.loadCustom();
    return repo;
  }

  testWidgets('experts list shows all builtins with badges', (tester) async {
    final repo = _newRepo();
    await tester.pumpWidget(CrewApp(
      home: ExpertsPage(templates: repo),
    ));
    await tester.pumpAndSettle();
    expect(find.text('小i（iOS 开发工程师）'), findsOneWidget);
    expect(find.text('产品（产品经理）'), findsOneWidget);
    expect(find.text('内置'), findsNWidgets(6));
  });

  testWidgets('tap expert opens edit page with prefilled fields', (tester) async {
    final repo = _newRepo();
    await tester.pumpWidget(CrewApp(
      home: ExpertsPage(templates: repo),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小i（iOS 开发工程师）'));
    await tester.pumpAndSettle();
    expect(find.text('编辑专家'), findsOneWidget);
    expect(find.text('基本信息'), findsOneWidget);
    // 内置模板编辑提示
    expect(find.text('这是内置模板。编辑后会保存为自定义版本，覆盖原内置模板。'), findsOneWidget);
  });

  testWidgets('save edited builtin creates custom override', (tester) async {
    final repo = _newRepo();
    await tester.pumpWidget(CrewApp(
      home: ExpertsPage(templates: repo),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小i（iOS 开发工程师）'));
    await tester.pumpAndSettle();
    // 修改显示名称（第 3 个 TextField: id=0, defaultName=1, displayName=2, role=3）
    await tester.enterText(find.byType(TextField).at(2), '小i改');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    // 回到列表页，显示自定义 badge
    expect(find.text('自定义'), findsOneWidget);
    expect(find.text('小i改（iOS 开发工程师）'), findsOneWidget);
  });

  testWidgets('AI refine updates probePrompt', (tester) async {
    final repo = _newRepo();
    String? capturedInstruction;
    String? capturedRole;
    await tester.pumpWidget(CrewApp(
      home: ExpertsPage(
        templates: repo,
        onAiRefine: ({
          required String role,
          required String currentPrompt,
          required String instruction,
        }) async {
          capturedRole = role;
          capturedInstruction = instruction;
          return '优化后的 prompt';
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小i（iOS 开发工程师）'));
    await tester.pumpAndSettle();
    // 点 AI 优化
    await tester.tap(find.byTooltip('AI 辅助优化'));
    await tester.pumpAndSettle();
    // 输入指令（对话框中的 TextField）
    await tester.enterText(find.byType(TextField).last, '更关注 SwiftUI');
    await tester.tap(find.text('优化'));
    await tester.pumpAndSettle();
    expect(capturedRole, 'iOS 开发工程师');
    expect(capturedInstruction, '更关注 SwiftUI');
    // probePrompt 字段位于长列表下方，向下滚动使其构建
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    // probePrompt 已被替换
    final probePromptField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '探查 prompt...',
    );
    expect(
      tester.widget<TextField>(probePromptField).controller?.text,
      '优化后的 prompt',
    );
  });

  testWidgets('new expert button creates custom template', (tester) async {
    final repo = _newRepo();
    await tester.pumpWidget(CrewApp(
      home: ExpertsPage(templates: repo),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建专家'));
    await tester.pumpAndSettle();
    expect(find.text('新建专家'), findsOneWidget);
    // 修改 ID（第 1 个 TextField）和默认名称（第 2 个）
    await tester.enterText(find.byType(TextField).at(0), 'rust-dev');
    await tester.enterText(find.byType(TextField).at(1), 'rust');
    // 显示名称（第 3 个）、角色（第 4 个）
    await tester.enterText(find.byType(TextField).at(2), '小R');
    await tester.enterText(find.byType(TextField).at(3), 'Rust 工程师');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    // 列表中出现新专家
    expect(find.text('小R（Rust 工程师）'), findsOneWidget);
  });

  testWidgets('new expert saves personality and principles', (tester) async {
    final repo = _newRepo();
    await tester.pumpWidget(CrewApp(
      home: ExpertsPage(templates: repo),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建专家'));
    await tester.pumpAndSettle();
    // 基本信息字段
    await tester.enterText(find.byType(TextField).at(0), 'perf-dev');
    await tester.enterText(find.byType(TextField).at(1), 'perf');
    await tester.enterText(find.byType(TextField).at(2), '小P');
    await tester.enterText(find.byType(TextField).at(3), '性能工程师');
    // 人格与判断标准（按 labelText 定位）
    final personalityField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '人格',
    );
    final principlesField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '判断标准',
    );
    await tester.enterText(personalityField, '严谨、重性能');
    await tester.enterText(principlesField, '主线程不做 IO, 依赖锁版本');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    // 仓库中已持久化正确值
    final saved = repo.resolve('perf-dev@1');
    expect(saved, isNotNull);
    expect(saved!.personality, '严谨、重性能');
    expect(saved.principles, ['主线程不做 IO', '依赖锁版本']);
  });

  testWidgets('edit page shows personality and principles initial values',
      (tester) async {
    final repo = _newRepo();
    await tester.pumpWidget(CrewApp(
      home: ExpertsPage(templates: repo),
    ));
    await tester.pumpAndSettle();
    // 打开 ios-dev（内置，含 personality/principles）
    await tester.tap(find.text('小i（iOS 开发工程师）'));
    await tester.pumpAndSettle();
    final original = kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev');
    final personalityField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '人格',
    );
    final principlesField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '判断标准',
    );
    expect(
      tester.widget<TextField>(personalityField).controller?.text,
      original.personality,
    );
    expect(
      tester.widget<TextField>(principlesField).controller?.text,
      original.principles.join(', '),
    );
  });

  testWidgets('builtin experts do not show delete button in list',
      (tester) async {
    final repo = _newRepo();
    await tester.pumpWidget(CrewApp(
      home: ExpertsPage(templates: repo),
    ));
    await tester.pumpAndSettle();
    // 内置模板列表中不应出现删除按钮
    expect(find.byTooltip('删除'), findsNothing);
  });

  testWidgets('custom experts show delete button and delete removes from list',
      (tester) async {
    final repo = _newRepo();
    // 直接添加一个自定义模板
    await repo.addCustom(const AgentTemplate(
      id: 'rust-dev',
      version: 1,
      defaultName: 'rust',
      displayName: '小R',
      role: 'Rust 工程师',
      probePrompt: '',
      matchGlobs: [],
    ));

    await tester.pumpWidget(CrewApp(
      home: ExpertsPage(templates: repo),
    ));
    await tester.pumpAndSettle();

    expect(find.text('小R（Rust 工程师）'), findsOneWidget);
    // 仅自定义专家有删除按钮
    expect(find.byTooltip('删除'), findsOneWidget);

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除专家'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    // 自定义专家已被移除，回到只剩内置专家（无删除按钮）
    expect(find.text('小R（Rust 工程师）'), findsNothing);
    expect(find.byTooltip('删除'), findsNothing);
  });
}
