// crew_gui/test/ui/end_to_end_smoke_test.dart
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/app.dart';
import 'package:crew_gui/app_scaffold.dart';
import 'package:crew_gui/services/directory_picker.dart';
import 'package:crew_gui/services/pipeline_factory.dart';
import 'package:crew_gui/services/project_store.dart';
import 'package:crew_gui/services/template_repository.dart';
import 'package:crew_gui/services/workspace_opener.dart';
import 'package:crew_gui/state/generation_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new project happy path generates a workspace', (tester) async {
    // Stepper 的 6 个步骤头部 + 当前步内容会超出默认 800x600 视口,
    // 导致"下一步"按钮落在屏幕外。设大视口让控件可点击。
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('e2e');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final iosDir = Directory('${tmp.path}/ios')..createSync();
    File('${iosDir.path}/Podfile').writeAsStringSync('');
    final wsParent = Directory('${tmp.path}/out')..createSync();

    final store = ProjectStore(File('${tmp.path}/projects.json'));
    final templates = TemplateRepository(File('${tmp.path}/custom.json'));
    await templates.loadCustom();

    // picker 依次返回：ios 目录（目录步）→ 生成位置（预览步）
    final pickQueue = <String?>[iosDir.path, wsParent.path];
    final picker = FakeDirectoryPicker(null);

    final fake = FakeRunner((dir, t) =>
        '{"role":"${t.role}","coordinates":"c","moduleStructure":"m","keyFiles":[],"dataflow":"","memoryConvention":"","conventions":[]}');

    await tester.pumpWidget(CrewApp(
      home: AppScaffold(
        store: store,
        templates: templates,
        picker: picker,
        opener: FakeWorkspaceOpener(),
        generationFactory: () => GenerationController(
          pipelineFactory: (c) => GenerationPipeline(
              runner: fake, adapters: adaptersFor(c.targets.toSet())),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 进入向导
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // 目录步：添加 ios 目录
    picker.next = pickQueue[0];
    await tester.tap(find.text('添加目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 专家步：选 ios-dev
    await tester.tap(find.text('iOS 开发工程师'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 关联步：自动分配
    await tester.tap(find.text('自动分配'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 目标步：默认 claude+codex，直接下一步
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 预览步：填名、选位置、生成预览、确认（下一步）
    await tester.enterText(find.byType(TextField).first, 'apm');
    picker.next = pickQueue[1];
    await tester.tap(find.text('选择位置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成预览'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    final wsRoot = '${wsParent.path}/apm';
    expect(File('$wsRoot/.claude/agents/ios.md').existsSync(), isTrue);
    expect(File('$wsRoot/crew.yaml').existsSync(), isTrue);
    expect((await store.load()).any((e) => e.name == 'apm'), isTrue);
  });
}
