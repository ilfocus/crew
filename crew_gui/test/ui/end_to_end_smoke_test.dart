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
    // 表单内容较长，设大视口以便底部按钮可点击。
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

    // picker 依次返回：ios 目录（目录步）→ 生成位置（项目信息）
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

    // 进入新建项目
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // 项目信息：项目名 + 生成位置
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '项目名 *',
      ),
      'apm',
    );
    picker.next = pickQueue[1];
    await tester.tap(find.text('选择位置'));
    await tester.pumpAndSettle();

    // 代码目录：添加 ios 目录
    picker.next = pickQueue[0];
    await tester.tap(find.text('添加目录'));
    await tester.pumpAndSettle();

    // 专家：选 ios-dev
    await tester.tap(find.text('iOS 开发工程师'));
    await tester.pumpAndSettle();

    // 关联：自动分配
    await tester.tap(find.text('自动分配'));
    await tester.pumpAndSettle();

    // 底部按钮：先生成预览
    await tester.tap(find.text('生成预览'));
    await tester.pumpAndSettle();

    // 再确认生成
    await tester.tap(find.text('确认生成'));
    await tester.pumpAndSettle();

    final wsRoot = '${wsParent.path}/apm';
    expect(File('$wsRoot/.claude/agents/ios.md').existsSync(), isTrue);
    expect(File('$wsRoot/crew.yaml').existsSync(), isTrue);
    expect((await store.load()).any((e) => e.name == 'apm'), isTrue);

    // 完成态：可看到「打开文件夹」按钮
    expect(find.textContaining('生成完成'), findsOneWidget);
  });
}
