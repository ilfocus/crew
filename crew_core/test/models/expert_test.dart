// crew_core/test/models/expert_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryEntry', () {
    test('toJson/fromJson round-trip', () {
      const e = MemoryEntry('solved/foo.md', 'fixed memory leak');
      final j = e.toJson();
      expect(j, {'path': 'solved/foo.md', 'content': 'fixed memory leak'});
      final r = MemoryEntry.fromJson(j);
      expect(r.path, 'solved/foo.md');
      expect(r.content, 'fixed memory leak');
    });

    test('fromJson tolerates missing content', () {
      final r = MemoryEntry.fromJson({'path': 'p'});
      expect(r.path, 'p');
      expect(r.content, '');
    });
  });

  group('ProjectRef', () {
    test('toJson/fromJson round-trip', () {
      const r = ProjectRef('github.com/foo/bar', 'iOS APM SDK');
      final j = r.toJson();
      expect(j, {'id': 'github.com/foo/bar', 'summary': 'iOS APM SDK'});
      final restored = ProjectRef.fromJson(j);
      expect(restored.id, 'github.com/foo/bar');
      expect(restored.summary, 'iOS APM SDK');
    });

    test('fromJson tolerates missing summary', () {
      final r = ProjectRef.fromJson({'id': 'x'});
      expect(r.id, 'x');
      expect(r.summary, '');
    });
  });

  group('ExpertMemory', () {
    test('toJson/fromJson round-trip with all fields', () {
      const m = ExpertMemory(
        index: '# MEMORY',
        notes: 'project notes L1',
        solved: [MemoryEntry('solved/a.md', 'fix A')],
        playbooks: [MemoryEntry('playbooks/b.md', 'play B')],
        projects: [ProjectRef('github.com/foo/bar', 'proj1')],
      );
      final j = m.toJson();
      final r = ExpertMemory.fromJson(j);
      expect(r.index, '# MEMORY');
      expect(r.notes, 'project notes L1');
      expect(r.solved.length, 1);
      expect(r.solved.first.path, 'solved/a.md');
      expect(r.solved.first.content, 'fix A');
      expect(r.playbooks.length, 1);
      expect(r.playbooks.first.path, 'playbooks/b.md');
      expect(r.projects.length, 1);
      expect(r.projects.first.id, 'github.com/foo/bar');
    });

    test('fromJson with empty map yields defaults', () {
      final r = ExpertMemory.fromJson({});
      expect(r.index, '');
      expect(r.notes, '');
      expect(r.solved, isEmpty);
      expect(r.playbooks, isEmpty);
      expect(r.projects, isEmpty);
    });
  });

  group('ExpertMeta defaults', () {
    test('default values via const constructor', () {
      const m = ExpertMeta();
      expect(m.source, 'private');
      expect(m.retention, 'full');
      expect(m.version, 1);
      expect(m.github, '');
      expect(m.projectId, '');
      expect(m.learnedProjectIds, isEmpty);
    });

    test('default values via fromJson on empty map', () {
      final m = ExpertMeta.fromJson({});
      expect(m.source, 'private');
      expect(m.retention, 'full');
      expect(m.version, 1);
      expect(m.github, '');
      expect(m.projectId, '');
      expect(m.learnedProjectIds, isEmpty);
    });

    test('toJson/fromJson round-trip with all fields', () {
      const m = ExpertMeta(
        source: 'opensource',
        github: 'https://github.com/foo/bar',
        retention: 'experience-only',
        projectId: 'github.com/foo/bar',
        version: 3,
        learnedProjectIds: ['github.com/foo/bar', 'github.com/x/y'],
      );
      final j = m.toJson();
      final r = ExpertMeta.fromJson(j);
      expect(r.source, 'opensource');
      expect(r.github, 'https://github.com/foo/bar');
      expect(r.retention, 'experience-only');
      expect(r.projectId, 'github.com/foo/bar');
      expect(r.version, 3);
      expect(r.learnedProjectIds, ['github.com/foo/bar', 'github.com/x/y']);
    });

    test('fromJson version coerces num to int', () {
      final m = ExpertMeta.fromJson({'version': 5});
      expect(m.version, 5);
    });
  });

  group('Expert project round-trip', () {
    test('full project expert toJson/fromJson preserves all fields', () {
      const spec = AgentSpec(
        name: 'ios',
        displayName: '小i',
        repos: ['~/bm_app/ios'],
        role: 'iOS 开发工程师',
        coordinates: '路径 ~/bm_app/ios',
        moduleStructure: 'Core/ 单例',
        keyFiles: [KeyFile('Core/BMApm.swift:279', '上报总线')],
        dataflow: '采集 → 神策',
        memoryConvention: '开工前读 MEMORY.md',
        conventions: ['默认在 develop/apm 工作'],
        personality: '严谨',
        principles: ['不引入未测试依赖'],
        techStack: ['Swift', 'SwiftUI'],
        sdks: ['SensorsSDK'],
        difficulties: ['线程安全'],
        source: 'opensource',
        github: 'https://github.com/foo/bar',
      );
      const memory = ExpertMemory(
        index: '# MEMORY',
        notes: 'L1 notes',
        solved: [MemoryEntry('solved/x.md', 'content x')],
        playbooks: [MemoryEntry('playbooks/y.md', 'content y')],
      );
      const meta = ExpertMeta(
        source: 'opensource',
        github: 'https://github.com/foo/bar',
        retention: 'full',
        projectId: 'github.com/foo/bar',
        version: 2,
      );
      const expert = Expert(
        kind: ExpertKind.project,
        spec: spec,
        memory: memory,
        meta: meta,
      );

      final json = expert.toJson();
      expect(json['kind'], 'project');
      expect(json['domain'], '');

      final r = Expert.fromJson(json);

      // top-level
      expect(r.kind, ExpertKind.project);
      expect(r.domain, '');

      // spec fields preserved
      expect(r.spec.name, 'ios');
      expect(r.spec.displayName, '小i');
      expect(r.spec.repos, ['~/bm_app/ios']);
      expect(r.spec.role, 'iOS 开发工程师');
      expect(r.spec.coordinates, '路径 ~/bm_app/ios');
      expect(r.spec.moduleStructure, 'Core/ 单例');
      expect(r.spec.keyFiles.length, 1);
      expect(r.spec.keyFiles.first.path, 'Core/BMApm.swift:279');
      expect(r.spec.keyFiles.first.purpose, '上报总线');
      expect(r.spec.dataflow, '采集 → 神策');
      expect(r.spec.memoryConvention, '开工前读 MEMORY.md');
      expect(r.spec.conventions, ['默认在 develop/apm 工作']);
      expect(r.spec.personality, '严谨');
      expect(r.spec.principles, ['不引入未测试依赖']);
      expect(r.spec.techStack, ['Swift', 'SwiftUI']);
      expect(r.spec.sdks, ['SensorsSDK']);
      expect(r.spec.difficulties, ['线程安全']);
      expect(r.spec.source, 'opensource');
      expect(r.spec.github, 'https://github.com/foo/bar');

      // memory fields preserved
      expect(r.memory.index, '# MEMORY');
      expect(r.memory.notes, 'L1 notes');
      expect(r.memory.solved.length, 1);
      expect(r.memory.solved.first.path, 'solved/x.md');
      expect(r.memory.solved.first.content, 'content x');
      expect(r.memory.playbooks.length, 1);
      expect(r.memory.playbooks.first.path, 'playbooks/y.md');
      expect(r.memory.projects, isEmpty);

      // meta fields preserved
      expect(r.meta.source, 'opensource');
      expect(r.meta.github, 'https://github.com/foo/bar');
      expect(r.meta.retention, 'full');
      expect(r.meta.projectId, 'github.com/foo/bar');
      expect(r.meta.version, 2);
      expect(r.meta.learnedProjectIds, isEmpty);
    });
  });

  group('Expert domain round-trip', () {
    test('full domain expert toJson/fromJson preserves projects and learnedProjectIds', () {
      const spec = AgentSpec(
        name: 'ios-domain',
        displayName: 'iOS 领域专家',
        repos: [],
        role: 'iOS 领域工程师',
        coordinates: '',
        moduleStructure: '',
        keyFiles: [],
        dataflow: '',
        memoryConvention: '',
        conventions: [],
      );
      const memory = ExpertMemory(
        index: '# DOMAIN MEMORY',
        notes: 'L2 domain notes',
        solved: [MemoryEntry('solved/d1.md', 'domain solved')],
        playbooks: [MemoryEntry('playbooks/d2.md', 'domain playbook')],
        projects: [
          ProjectRef('github.com/foo/bar', 'iOS APM SDK'),
          ProjectRef('github.com/x/y', 'iOS networking'),
        ],
      );
      const meta = ExpertMeta(
        source: 'opensource',
        github: '',
        retention: 'experience-only',
        projectId: '',
        version: 1,
        learnedProjectIds: ['github.com/foo/bar', 'github.com/x/y'],
      );
      const expert = Expert(
        kind: ExpertKind.domain,
        domain: 'ios',
        spec: spec,
        memory: memory,
        meta: meta,
      );

      final json = expert.toJson();
      expect(json['kind'], 'domain');
      expect(json['domain'], 'ios');

      final r = Expert.fromJson(json);
      expect(r.kind, ExpertKind.domain);
      expect(r.domain, 'ios');
      expect(r.spec.name, 'ios-domain');
      expect(r.spec.displayName, 'iOS 领域专家');
      expect(r.memory.notes, 'L2 domain notes');
      expect(r.memory.projects.length, 2);
      expect(r.memory.projects[0].id, 'github.com/foo/bar');
      expect(r.memory.projects[0].summary, 'iOS APM SDK');
      expect(r.memory.projects[1].id, 'github.com/x/y');
      expect(r.memory.projects[1].summary, 'iOS networking');
      expect(r.meta.retention, 'experience-only');
      expect(r.meta.projectId, '');
      expect(r.meta.learnedProjectIds,
          ['github.com/foo/bar', 'github.com/x/y']);
    });
  });

  group('Expert minimal fromJson', () {
    test('fromJson with minimal data does not throw and uses defaults', () {
      final json = {
        'kind': 'project',
        'spec': {
          'name': 'n',
          'displayName': 'd',
          'repos': <String>[],
        },
        'memory': <String, dynamic>{},
        'meta': <String, dynamic>{},
      };
      final r = Expert.fromJson(json);
      expect(r.kind, ExpertKind.project);
      expect(r.domain, '');
      expect(r.spec.name, 'n');
      expect(r.spec.displayName, 'd');
      expect(r.spec.repos, isEmpty);
      expect(r.spec.role, '');
      expect(r.memory.index, '');
      expect(r.memory.notes, '');
      expect(r.memory.solved, isEmpty);
      expect(r.memory.projects, isEmpty);
      // Meta defaults kick in
      expect(r.meta.source, 'private');
      expect(r.meta.retention, 'full');
      expect(r.meta.version, 1);
      expect(r.meta.projectId, '');
      expect(r.meta.learnedProjectIds, isEmpty);
    });

    test('fromJson tolerates missing domain key', () {
      final r = Expert.fromJson({
        'kind': 'domain',
        'spec': {
          'name': 'n',
          'displayName': 'd',
          'repos': <String>[],
        },
        'memory': {},
        'meta': {},
      });
      expect(r.kind, ExpertKind.domain);
      expect(r.domain, '');
    });

    test('fromJson defaults unknown kind to project', () {
      final r = Expert.fromJson({
        'kind': 'unknown',
        'spec': {
          'name': 'n',
          'displayName': 'd',
          'repos': <String>[],
        },
        'memory': {},
        'meta': {},
      });
      expect(r.kind, ExpertKind.project);
    });
  });
}
