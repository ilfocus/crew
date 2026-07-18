// crew_cli/test/list_experts_test.dart
import 'dart:io';

import 'package:crew_cli/src/commands/list_experts.dart';
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

AgentCore _core(String id, {String displayName = 'D', String role = 'role'}) =>
    AgentCore(
      id: id,
      name: id,
      displayName: displayName,
      role: role,
   );

void main() {
  late Directory poolDir;
  late AgentPool pool;

  setUp(() {
    poolDir = Directory.systemTemp.createTempSync('list_pool');
    pool = AgentPool(poolDir);
  });

  tearDown(() => poolDir.deleteSync(recursive: true));

  group('runListExperts', () {
    test('prints agent summary with domains and project count', () async {
      await pool.save(AgentProfile(
        core: _core('ios-lin', displayName: '小i'),
        meta: const AgentMeta(version: 1),
      ));
      await pool.saveDomain(
        'ios-lin',
        DomainExpertise(domain: 'ios'),
      );
      await pool.saveProject(
        'ios-lin',
        const ProjectCompetence(
          projectId: 'github.com/foo/bar',
          retention: 'full',
        ),
      );

      final buf = StringBuffer();
      await runListExperts(poolDir: poolDir, out: buf);
      final output = buf.toString();

      expect(output, contains('ios-lin'));
      expect(output, contains('小i'));
      expect(output, contains('ios'));
      expect(output, contains('1')); // project count or version
      // Header present.
      expect(output, contains('AGENT'));
      expect(output, contains('DISPLAY'));
      expect(output, contains('DOMAINS'));
      expect(output, contains('PROJECTS'));
      expect(output, contains('VERSION'));
    });

    test('prints multiple agents sorted by list scan order', () async {
      await pool.save(AgentProfile(
        core: _core('ios-lin', displayName: '小i'),
        meta: const AgentMeta(version: 1),
      ));
      await pool.save(AgentProfile(
        core: _core('android-wang', displayName: '老王'),
        meta: const AgentMeta(version: 2),
      ));

      final buf = StringBuffer();
      await runListExperts(poolDir: poolDir, out: buf);
      final output = buf.toString();

      expect(output, contains('ios-lin'));
      expect(output, contains('小i'));
      expect(output, contains('android-wang'));
      expect(output, contains('老王'));
    });

    test('agent with multiple domains lists all domain names', () async {
      await pool.save(AgentProfile(
        core: _core('multi', displayName: 'M'),
        meta: const AgentMeta(version: 1),
      ));
      await pool.saveDomain('multi', DomainExpertise(domain: 'ios'));
      await pool.saveDomain('multi', DomainExpertise(domain: 'apm'));

      final buf = StringBuffer();
      await runListExperts(poolDir: poolDir, out: buf);
      final output = buf.toString();

      expect(output, contains('ios'));
      expect(output, contains('apm'));
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
