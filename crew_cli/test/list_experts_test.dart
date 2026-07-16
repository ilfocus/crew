// crew_cli/test/list_experts_test.dart
import 'dart:io';

import 'package:crew_cli/src/commands/list_experts.dart';
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

AgentSpec _spec(String name, {String displayName = 'D'}) => AgentSpec(
      name: name,
      displayName: displayName,
      repos: const [],
      role: 'role',
      coordinates: '',
      moduleStructure: '',
      keyFiles: const [],
      dataflow: '',
      memoryConvention: '',
      conventions: const [],
      personality: '',
      principles: const [],
      techStack: const [],
      sdks: const [],
      difficulties: const [],
      source: 'private',
      github: '',
    );

void main() {
  late Directory poolDir;

  setUp(() {
    poolDir = Directory.systemTemp.createTempSync('list_pool');
  });

  tearDown(() => poolDir.deleteSync(recursive: true));

  group('runListExperts', () {
    test('prints both project and domain experts', () async {
      final pool = ExpertPool(poolDir);
      await pool.saveProject(Expert(
        kind: ExpertKind.project,
        spec: _spec('ios', displayName: '小i'),
        memory: const ExpertMemory(),
        meta: const ExpertMeta(projectId: 'github.com/foo/bar', version: 2),
      ));
      await pool.saveDomain(Expert(
        kind: ExpertKind.domain,
        domain: 'ios',
        spec: _spec('ios-domain', displayName: 'iOS 领域专家'),
        memory: const ExpertMemory(),
        meta: const ExpertMeta(version: 1),
      ));

      final buf = StringBuffer();
      await runListExperts(poolDir: poolDir, out: buf);
      final output = buf.toString();

      expect(output, contains('project'));
      expect(output, contains('github.com/foo/bar'));
      expect(output, contains('domain'));
      expect(output, contains('ios'));
      // Header present.
      expect(output, contains('KIND'));
      expect(output, contains('ID/DOMAIN'));
      expect(output, contains('VERSION'));
    });

    test('prints empty message when pool is empty', () async {
      final buf = StringBuffer();
      await runListExperts(poolDir: poolDir, out: buf);
      final output = buf.toString();

      expect(output, contains('empty'));
    });

    test('prints empty message when pool dir does not exist', () async {
      final buf = StringBuffer();
      await runListExperts(
        poolDir: Directory('${poolDir.path}/nope'),
        out: buf,
      );
      final output = buf.toString();

      expect(output, contains('empty'));
    });
  });
}
