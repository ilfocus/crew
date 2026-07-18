// crew_core/test/models/domain_project_competence_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  group('DomainExpertise', () {
    test('toJson/fromJson round-trip with all fields', () {
      const d = DomainExpertise(
        domain: 'ios',
        notes: 'L2 领域经验：iOS 内存管理',
        principles: ['线程安全优先', '避免 retain cycle'],
        playbooks: [MemoryEntry('playbooks/swift-actor.md', 'actor 心得')],
        projects: [
          ProjectRef('github.com/foo/bar', 'iOS APM'),
          ProjectRef('github.com/x/y', 'iOS 网络'),
        ],
      );
      final j = d.toJson();
      expect(j['domain'], 'ios');
      expect(j['notes'], 'L2 领域经验：iOS 内存管理');
      expect(j['principles'], ['线程安全优先', '避免 retain cycle']);
      expect((j['playbooks'] as List).length, 1);
      expect((j['projects'] as List).length, 2);

      final r = DomainExpertise.fromJson(j);
      expect(r.domain, 'ios');
      expect(r.notes, 'L2 领域经验：iOS 内存管理');
      expect(r.principles, ['线程安全优先', '避免 retain cycle']);
      expect(r.playbooks.length, 1);
      expect(r.playbooks.first.path, 'playbooks/swift-actor.md');
      expect(r.projects.length, 2);
      expect(r.projects[0].id, 'github.com/foo/bar');
      expect(r.projects[1].id, 'github.com/x/y');
    });

    test('fromJson with empty map yields defaults', () {
      final r = DomainExpertise.fromJson({});
      expect(r.domain, '');
      expect(r.notes, '');
      expect(r.principles, isEmpty);
      expect(r.playbooks, isEmpty);
      expect(r.projects, isEmpty);
    });

    test('projects list is multi-valued (same project can be in many domains)',
        () {
      // 同 project-id 可同时出现在多个 DomainExpertise.projects 里
      const d1 = DomainExpertise(domain: 'ios', projects: [
        ProjectRef('github.com/foo/bar', 'iOS 视角'),
      ]);
      const d2 = DomainExpertise(domain: 'quant', projects: [
        ProjectRef('github.com/foo/bar', '量化视角'),
      ]);
      expect(d1.projects.single.id, d2.projects.single.id);
      expect(d1.domain, isNot(d2.domain));
    });
  });

  group('ProjectCompetence', () {
    test('toJson/fromJson round-trip with all fields', () {
      const p = ProjectCompetence(
        projectId: 'github.com/foo/bar',
        repos: ['~/bm_app/ios'],
        coordinates: 'Core/BMApm',
        moduleStructure: 'Core/ 单例',
        keyFiles: [KeyFile('Core/BMApm.swift:279', '上报总线')],
        dataflow: '采集 → 神策',
        techStack: ['Swift', 'SwiftUI'],
        sdks: ['SensorsSDK'],
        difficulties: ['线程安全'],
        github: 'https://github.com/foo/bar',
        source: 'opensource',
        retention: 'full',
        notes: 'L1 项目笔记',
        solved: [MemoryEntry('solved/leak.md', '修了内存泄漏')],
        playbooks: [MemoryEntry('playbooks/apm.md', 'APM 套路')],
        domains: ['ios', 'apm'],
      );
      final j = p.toJson();
      expect(j['projectId'], 'github.com/foo/bar');
      expect(j['repos'], ['~/bm_app/ios']);
      expect(j['coordinates'], 'Core/BMApm');
      expect(j['moduleStructure'], 'Core/ 单例');
      expect((j['keyFiles'] as List).length, 1);
      expect(j['dataflow'], '采集 → 神策');
      expect(j['techStack'], ['Swift', 'SwiftUI']);
      expect(j['sdks'], ['SensorsSDK']);
      expect(j['difficulties'], ['线程安全']);
      expect(j['github'], 'https://github.com/foo/bar');
      expect(j['source'], 'opensource');
      expect(j['retention'], 'full');
      expect(j['notes'], 'L1 项目笔记');
      expect((j['solved'] as List).length, 1);
      expect((j['playbooks'] as List).length, 1);
      expect(j['domains'], ['ios', 'apm']);

      final r = ProjectCompetence.fromJson(j);
      expect(r.projectId, 'github.com/foo/bar');
      expect(r.repos, ['~/bm_app/ios']);
      expect(r.coordinates, 'Core/BMApm');
      expect(r.moduleStructure, 'Core/ 单例');
      expect(r.keyFiles.length, 1);
      expect(r.keyFiles.first.path, 'Core/BMApm.swift:279');
      expect(r.dataflow, '采集 → 神策');
      expect(r.techStack, ['Swift', 'SwiftUI']);
      expect(r.sdks, ['SensorsSDK']);
      expect(r.difficulties, ['线程安全']);
      expect(r.github, 'https://github.com/foo/bar');
      expect(r.source, 'opensource');
      expect(r.retention, 'full');
      expect(r.notes, 'L1 项目笔记');
      expect(r.solved.length, 1);
      expect(r.solved.first.content, '修了内存泄漏');
      expect(r.playbooks.length, 1);
      expect(r.domains, ['ios', 'apm']);
    });

    test('fromJson with empty map yields defaults', () {
      final r = ProjectCompetence.fromJson({});
      expect(r.projectId, '');
      expect(r.repos, isEmpty);
      expect(r.coordinates, '');
      expect(r.moduleStructure, '');
      expect(r.keyFiles, isEmpty);
      expect(r.dataflow, '');
      expect(r.techStack, isEmpty);
      expect(r.sdks, isEmpty);
      expect(r.difficulties, isEmpty);
      expect(r.github, '');
      expect(r.source, 'private');
      expect(r.retention, 'full');
      expect(r.notes, '');
      expect(r.solved, isEmpty);
      expect(r.playbooks, isEmpty);
      expect(r.domains, isEmpty);
    });

    test('domains list supports multi-valued inverse index', () {
      // 一个 project 可同时归属多个 domain
      const p = ProjectCompetence(
        projectId: 'p1',
        domains: ['ios', 'quant', 'apm'],
      );
      expect(p.domains.length, 3);
      expect(p.domains, contains('ios'));
      expect(p.domains, contains('quant'));
      expect(p.domains, contains('apm'));
    });

    test('default source is private, default retention is full', () {
      const p = ProjectCompetence(projectId: 'p');
      expect(p.source, 'private');
      expect(p.retention, 'full');
    });
  });
}
