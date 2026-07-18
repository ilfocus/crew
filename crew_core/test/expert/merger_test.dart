// crew_core/test/expert/merger_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

ProjectCompetence _project({String projectId = 'github.com/foo/bar'}) {
  return ProjectCompetence(
    projectId: projectId,
    repos: const ['~/bm_app/ios'],
    coordinates: 'Core/BMApm',
    moduleStructure: 'Core/ 单例',
    keyFiles: const [KeyFile('Core/Foo.swift', '上报总线')],
    dataflow: '采集 → 神策',
    techStack: const ['Swift', 'SwiftUI'],
    sdks: const ['SensorsSDK'],
    difficulties: const ['线程安全'],
    source: 'opensource',
    github: 'https://github.com/foo/bar',
    retention: 'full',
    notes: 'L1 notes',
    solved: const [MemoryEntry('solved/x.md', 'fix X')],
    playbooks: const [MemoryEntry('playbooks/old.md', 'old playbook')],
  );
}

DomainExpertise _emptyDomain(String name) => DomainExpertise(domain: name);

FakeRunner _runnerWith(String notes, String playbookPath) => FakeRunner(
      (dir, t) => '{}',
      distillResponder: (prompt) => '{"domainNotes":"$notes",'
          '"playbooks":[{"path":"$playbookPath","content":"步骤"}]}',
    );

void main() {
  group('mergeIntoDomain — empty domain + one project', () {
    test('domain gets distill notes/playbooks; projects has 1; project.domains has 1',
        () async {
      final project = _project();
      final runner = _runnerWith('iOS 通用抽象', '排查-内存.md');

      final out = await mergeIntoDomain(
        domain: _emptyDomain('ios'),
        project: project,
        runner: runner,
      );

      // distill output 合并进 domain.notes
      expect(out.domain.notes, contains('iOS 通用抽象'));
      expect(out.domain.playbooks.length, 1);
      expect(out.domain.playbooks.first.path, '排查-内存.md');

      // domain.projects 加 1 条
      expect(out.domain.projects.length, 1);
      expect(out.domain.projects.first.id, 'github.com/foo/bar');

      // project.domains 反向索引加 1 条
      expect(out.project.domains, contains('ios'));
    });
  });

  group('mergeIntoDomain — idempotency (same project, same domain)', () {
    test('merging twice does not duplicate projects or domains', () async {
      final project = _project();
      final runner = _runnerWith('抽象', '排查-内存.md');

      final d1 = await mergeIntoDomain(
        domain: _emptyDomain('ios'),
        project: project,
        runner: runner,
      );
      // 第二次：domain 已含此 project 的 ref
      final d2 = await mergeIntoDomain(
        domain: d1.domain,
        project: d1.project, // project.domains 已含 ios
        runner: runner,
      );

      // projects 不重复
      expect(d2.domain.projects.length, 1);
      expect(d2.domain.projects.first.id, 'github.com/foo/bar');
      // project.domains 不重复
      expect(d2.project.domains, ['ios']);
      // playbooks 按 path 去重
      expect(d2.domain.playbooks.length, 1);
      expect(d2.domain.playbooks.first.path, '排查-内存.md');
    });
  });

  group('mergeIntoDomain — multi-many (same project → multiple domains)', () {
    test('both domains reference the project; project.domains grows to 2',
        () async {
      final project = _project();
      final runner = _runnerWith('抽象', '排查-通用.md');

      // 第一次：并入 ios domain
      final m1 = await mergeIntoDomain(
        domain: _emptyDomain('ios'),
        project: project,
        runner: runner,
      );
      // 第二次：把（已含 ios 反向索引的）project 并入 apm domain
      final m2 = await mergeIntoDomain(
        domain: _emptyDomain('apm'),
        project: m1.project,
        runner: runner,
      );

      // 两个 domain 都引用该 project
      expect(m1.domain.projects.first.id, 'github.com/foo/bar');
      expect(m2.domain.projects.first.id, 'github.com/foo/bar');

      // project 反向索引增到 2
      expect(m2.project.domains.toSet(), {'ios', 'apm'});
    });

    test(
        'merging the same project back into the first domain after second domain '
        'does not duplicate either side', () async {
      final project = _project();
      final runner = _runnerWith('抽象', '排查-通用.md');

      // ios ← project
      final m1 = await mergeIntoDomain(
        domain: _emptyDomain('ios'),
        project: project,
        runner: runner,
      );
      // apm ← (project with ios ref)
      final m2 = await mergeIntoDomain(
        domain: _emptyDomain('apm'),
        project: m1.project,
        runner: runner,
      );
      // 再次 ios ← (project with ios+apm refs)
      final m3 = await mergeIntoDomain(
        domain: m1.domain, // ios domain 已有该 project
        project: m2.project,
        runner: runner,
      );

      // project.domains 仍只有 2
      expect(m3.project.domains.toSet(), {'ios', 'apm'});
      // ios domain 的 projects 仍只有 1
      expect(m3.domain.projects.length, 1);
    });
  });

  group('mergeIntoDomain — notes append', () {
    test('distill notes appended to existing domain notes with separator',
        () async {
      const existing = DomainExpertise(
        domain: 'ios',
        notes: '已有 L2',
      );
      final runner = _runnerWith('新抽象', '排查-X.md');

      final out = await mergeIntoDomain(
        domain: existing,
        project: _project(),
        runner: runner,
      );

      expect(out.domain.notes, contains('已有 L2'));
      expect(out.domain.notes, contains('新抽象'));
      expect(out.domain.notes, contains('---'));
    });

    test('empty existing notes replaced by distill notes', () async {
      final runner = _runnerWith('首批抽象', '排查-X.md');
      final out = await mergeIntoDomain(
        domain: _emptyDomain('ios'),
        project: _project(),
        runner: runner,
      );
      expect(out.domain.notes, '首批抽象');
    });
  });

  group('mergeIntoDomain — playbooks dedup', () {
    test('existing + distill playbooks merged by path (no duplicates)', () async {
      const existing = DomainExpertise(
        domain: 'ios',
        playbooks: [
          MemoryEntry('排查-A.md', 'old A'),
          MemoryEntry('排查-B.md', 'old B'),
        ],
      );
      // distill 又吐出一个 A（同 path，新 content）+ 一个 C（新 path）
      final runner = FakeRunner(
        (dir, t) => '{}',
        distillResponder: (prompt) => '{"domainNotes":"n",'
            '"playbooks":['
            '{"path":"排查-A.md","content":"new A"},'
            '{"path":"排查-C.md","content":"C"}'
            ']}',
      );

      final out = await mergeIntoDomain(
        domain: existing,
        project: _project(),
        runner: runner,
      );

      // A 保留旧版（已存在不覆盖），B 还在，C 新加 → 3 条
      expect(out.domain.playbooks.length, 3);
      final paths = out.domain.playbooks.map((p) => p.path).toSet();
      expect(paths, {'排查-A.md', '排查-B.md', '排查-C.md'});
      // A 内容保留旧版
      final a = out.domain.playbooks.firstWhere((p) => p.path == '排查-A.md');
      expect(a.content, 'old A');
    });
  });

  group('mergeIntoDomain — project summary', () {
    test('uses role or displayName or projectId as summary', () async {
      final runner = _runnerWith('n', 'p.md');
      // role='iOS APM' 应作为 summary
      final p = _project();
      final out = await mergeIntoDomain(
        domain: _emptyDomain('ios'),
        project: p,
        runner: runner,
      );
      // ProjectCompetence 没有独立的 role/displayName 字段——summary 回退到 projectId
      expect(out.domain.projects.first.summary, 'github.com/foo/bar');
      expect(out.domain.projects.first.id, 'github.com/foo/bar');
    });
  });
}
