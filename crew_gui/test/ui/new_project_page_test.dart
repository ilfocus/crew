// crew_gui/test/ui/new_project_page_test.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/services/directory_picker.dart';
import 'package:crew_gui/services/pipeline_factory.dart';
import 'package:crew_gui/services/project_store.dart';
import 'package:crew_gui/services/template_repository.dart';
import 'package:crew_gui/services/workspace_opener.dart';
import 'package:crew_gui/state/generation_controller.dart';
import 'package:crew_gui/state/wizard_controller.dart';
import 'package:crew_gui/ui/new_project_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('autoDetect button selects templates and shows signal chips',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('np_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final iosDir = Directory('${tmp.path}/ios')..createSync();
    File('${iosDir.path}/Podfile').writeAsStringSync(
        "platform :ios, '15.0'\ntarget 'App' do\nend\n");

    final store = ProjectStore(File('${tmp.path}/projects.json'));
    final templates = TemplateRepository(File('${tmp.path}/custom.json'));
    await templates.loadCustom();

    final wizard = WizardController();
    final generation = GenerationController(
      pipelineFactory: (c) => GenerationPipeline(
          runner: FakeRunner((_, __) =>
              '{"role":"r","coordinates":"c","moduleStructure":"m","keyFiles":[],"dataflow":"","memoryConvention":"","conventions":[]}'),
          adapters: adaptersFor(c.targets.toSet())),
    );

    // 添加 iOS 目录
    wizard.addDirectory(iosDir.path);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NewProjectPage(
          wizard: wizard,
          templates: templates,
          picker: FakeDirectoryPicker(null),
          generation: generation,
          opener: FakeWorkspaceOpener(),
          store: store,
          onDone: () {},
        ),
      ),
    ));

    // 初始状态：专家未选中
    expect(wizard.selectedTemplates, isEmpty);

    // 点智能识别按钮
    await tester.tap(find.text('智能识别'));
    await tester.pumpAndSettle();

    // ios-dev + pm 都被选中
    expect(wizard.selectedTemplates.any((t) => t.id == 'ios-dev'), isTrue);
    expect(wizard.selectedTemplates.any((t) => t.id == 'pm'), isTrue);

    // 卡片上有信号 chip：iOS 开发工程师卡片上能找到至少 1 个闪电图标
    final iosCard = find.ancestor(
      of: find.text('iOS 开发工程师'),
      matching: find.byType(Material),
    );
    expect(
      find.descendant(of: iosCard, matching: find.byIcon(Icons.bolt)),
      findsWidgets,
    );

    // 说明文字更新为「已识别 N 条匹配」
    expect(find.textContaining('已识别'), findsOneWidget);
  });

  testWidgets('autoDetect button is disabled when no directories',
      (tester) async {
    // 表单内容较长，设大视口确保「专家」区块渲染出来
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('np_empty');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final store = ProjectStore(File('${tmp.path}/projects.json'));
    final templates = TemplateRepository(File('${tmp.path}/custom.json'));
    await templates.loadCustom();

    final wizard = WizardController();
    final generation = GenerationController(
      pipelineFactory: (c) => GenerationPipeline(
          runner: FakeRunner((_, __) =>
              '{"role":"r","coordinates":"c","moduleStructure":"m","keyFiles":[],"dataflow":"","memoryConvention":"","conventions":[]}'),
          adapters: adaptersFor(c.targets.toSet())),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NewProjectPage(
          wizard: wizard,
          templates: templates,
          picker: FakeDirectoryPicker(null),
          generation: generation,
          opener: FakeWorkspaceOpener(),
          store: store,
          onDone: () {},
        ),
      ),
    ));

    expect(find.text('先添加代码目录，再点智能识别'), findsOneWidget);

    // 智能识别按钮存在（通过 auto_awesome icon 定位）
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    // OutlinedButton.icon 在 Flutter 3.35 中实际类型是 _OutlinedButtonWithIcon（OutlinedButton 子类），
    // 用 bySubtype 匹配后，找到包含 auto_awesome icon 的那个按钮，验证其 onPressed 为 null（disabled）。
    final autoAwesomeIcon = find.byIcon(Icons.auto_awesome);
    final btnFinder = find.ancestor(
      of: autoAwesomeIcon,
      matching: find.bySubtype<OutlinedButton>(),
    );
    expect(btnFinder, findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(btnFinder).onPressed,
      isNull,
    );
  });
}
