import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('ws'));
  tearDown(() => root.deleteSync(recursive: true));

  test('fresh workspace: all create, apply writes files and manifest', () async {
    final planner = WritePlanner();
    final arts = [
      const FileArtifact('CLAUDE.md', 'hi'),
      const FileArtifact('memory/ios/MEMORY.md', 'm', isMemory: true),
    ];
    final plan = planner.plan(root.path, arts);
    expect(plan.writes.every((w) => w.action == WriteAction.create), isTrue);

    await planner.apply(root.path, plan);
    expect(File('${root.path}/CLAUDE.md').readAsStringSync(), 'hi');
    expect(File('${root.path}/memory/ios/MEMORY.md').existsSync(), isTrue);
    expect(File('${root.path}/.crew/manifest.json').existsSync(), isTrue);
  });

  test('regen unchanged file -> overwrite; memory -> skip', () async {
    final planner = WritePlanner();
    final arts = [
      const FileArtifact('CLAUDE.md', 'v1'),
      const FileArtifact('memory/ios/MEMORY.md', 'm1', isMemory: true),
    ];
    await planner.apply(root.path, planner.plan(root.path, arts));

    // 第二次生成：CLAUDE.md 内容不变，记忆内容想改
    final plan2 = planner.plan(root.path, [
      const FileArtifact('CLAUDE.md', 'v1'),
      const FileArtifact('memory/ios/MEMORY.md', 'm2', isMemory: true),
    ]);
    final byPath = {for (final w in plan2.writes) w.artifact.relativePath: w.action};
    expect(byPath['CLAUDE.md'], WriteAction.overwrite);
    expect(byPath['memory/ios/MEMORY.md'], WriteAction.skip);
  });

  test('user-modified generated file -> writeNew (.new)', () async {
    final planner = WritePlanner();
    await planner.apply(root.path,
        planner.plan(root.path, [const FileArtifact('CLAUDE.md', 'v1')]));
    // 用户手改
    File('${root.path}/CLAUDE.md').writeAsStringSync('hand-edited');

    final plan2 = planner.plan(root.path, [const FileArtifact('CLAUDE.md', 'v2')]);
    final w = plan2.writes.single;
    expect(w.action, WriteAction.writeNew);
    expect(w.targetPath, 'CLAUDE.md.new');

    await planner.apply(root.path, plan2);
    expect(File('${root.path}/CLAUDE.md').readAsStringSync(), 'hand-edited');
    expect(File('${root.path}/CLAUDE.md.new').readAsStringSync(), 'v2');
  });
}
