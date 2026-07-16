// crew_core/test/expert/expert_pool_adapter_test.dart
import 'dart:convert';
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  const adapter = ExpertPoolAdapter();

  group('ExpertPoolAdapter — project expert', () {
    final expert = Expert(
      kind: ExpertKind.project,
      spec: const AgentSpec(
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
      ),
      memory: const ExpertMemory(
        index: '# MEMORY\n项目记忆索引',
        notes: 'L1 项目笔记',
        solved: [MemoryEntry('crash-fix.md', '修复了崩溃')],
        playbooks: [MemoryEntry('release.md', '发布流程')],
      ),
      meta: const ExpertMeta(
        source: 'opensource',
        github: 'https://github.com/foo/bar',
        retention: 'full',
        projectId: 'github.com/foo/bar',
        version: 2,
      ),
    );

    test('renders all expected paths for a project expert', () {
      final artifacts = adapter.render(expert);
      final paths = artifacts.map((a) => a.relativePath).toSet();

      expect(paths, contains('expert.json'));
      expect(paths, contains('IDENTITY.md'));
      expect(paths, contains('COMPETENCE.md'));
      expect(paths, contains('memory/MEMORY.md'));
      expect(paths, contains('memory/solved/crash-fix.md'));
      expect(paths, contains('memory/playbooks/release.md'));
      expect(paths, contains('memory/project-notes.md'));
      // Project experts must NOT emit domain-only files
      expect(paths, isNot(contains('memory/domain-notes.md')));
      expect(paths, isNot(contains('memory/projects.md')));
    });

    test('expert.json has isMemory false', () {
      final artifacts = adapter.render(expert);
      final ej = artifacts.firstWhere((a) => a.relativePath == 'expert.json');
      expect(ej.isMemory, isFalse);
    });

    test('IDENTITY.md and COMPETENCE.md have isMemory false', () {
      final artifacts = adapter.render(expert);
      final id = artifacts.firstWhere((a) => a.relativePath == 'IDENTITY.md');
      final comp =
          artifacts.firstWhere((a) => a.relativePath == 'COMPETENCE.md');
      expect(id.isMemory, isFalse);
      expect(comp.isMemory, isFalse);
    });

    test('all memory/* files have isMemory true', () {
      final artifacts = adapter.render(expert);
      final memoryArts = artifacts.where((a) => a.relativePath.startsWith('memory/'));
      expect(memoryArts, isNotEmpty);
      for (final a in memoryArts) {
        expect(a.isMemory, isTrue, reason: a.relativePath);
      }
    });

    test('expert.json round-trips through Expert.fromJson', () {
      final artifacts = adapter.render(expert);
      final ej = artifacts.firstWhere((a) => a.relativePath == 'expert.json');
      final decoded = jsonDecode(ej.content) as Map<String, dynamic>;
      final restored = Expert.fromJson(decoded);

      expect(restored.kind, ExpertKind.project);
      expect(restored.spec.name, 'ios');
      expect(restored.spec.displayName, '小i');
      expect(restored.spec.role, 'iOS 开发工程师');
      expect(restored.spec.personality, '严谨');
      expect(restored.spec.principles, ['不引入未测试依赖']);
      expect(restored.spec.techStack, ['Swift', 'SwiftUI']);
      expect(restored.spec.sdks, ['SensorsSDK']);
      expect(restored.spec.difficulties, ['线程安全']);
      expect(restored.spec.github, 'https://github.com/foo/bar');
      expect(restored.memory.index, '# MEMORY\n项目记忆索引');
      expect(restored.memory.notes, 'L1 项目笔记');
      expect(restored.memory.solved.length, 1);
      expect(restored.memory.solved.first.path, 'crash-fix.md');
      expect(restored.memory.solved.first.content, '修复了崩溃');
      expect(restored.memory.playbooks.length, 1);
      expect(restored.meta.projectId, 'github.com/foo/bar');
      expect(restored.meta.version, 2);
    });

    test('memory/MEMORY.md contains expert.memory.index content', () {
      final artifacts = adapter.render(expert);
      final mem = artifacts.firstWhere((a) => a.relativePath == 'memory/MEMORY.md');
      expect(mem.content, '# MEMORY\n项目记忆索引');
    });

    test('memory/project-notes.md contains expert.memory.notes content', () {
      final artifacts = adapter.render(expert);
      final notes =
          artifacts.firstWhere((a) => a.relativePath == 'memory/project-notes.md');
      expect(notes.content, 'L1 项目笔记');
    });

    test('IDENTITY.md contains role, personality, principles', () {
      final artifacts = adapter.render(expert);
      final id = artifacts.firstWhere((a) => a.relativePath == 'IDENTITY.md');
      expect(id.content, contains('iOS 开发工程师'));
      expect(id.content, contains('严谨'));
      expect(id.content, contains('不引入未测试依赖'));
    });

    test('COMPETENCE.md contains techStack, sdks, difficulties, github', () {
      final artifacts = adapter.render(expert);
      final comp =
          artifacts.firstWhere((a) => a.relativePath == 'COMPETENCE.md');
      expect(comp.content, contains('Swift'));
      expect(comp.content, contains('SensorsSDK'));
      expect(comp.content, contains('线程安全'));
      expect(comp.content, contains('https://github.com/foo/bar'));
      expect(comp.content, contains('Core/BMApm.swift:279'));
    });

    test('solved entry path with leading solved/ prefix is normalized', () {
      final e = Expert(
        kind: ExpertKind.project,
        spec: _minimalSpec('p'),
        memory: const ExpertMemory(
          solved: [MemoryEntry('solved/extra.md', 'content')],
          playbooks: [MemoryEntry('playbooks/pb.md', 'pb content')],
        ),
        meta: const ExpertMeta(projectId: 'pid'),
      );
      final artifacts = adapter.render(e);
      final paths = artifacts.map((a) => a.relativePath).toSet();
      // The leading solved/ prefix should be stripped, not doubled.
      expect(paths, contains('memory/solved/extra.md'));
      expect(paths, isNot(contains('memory/solved/solved/extra.md')));
      expect(paths, contains('memory/playbooks/pb.md'));
      expect(paths, isNot(contains('memory/playbooks/playbooks/pb.md')));
    });
  });

  group('ExpertPoolAdapter — domain expert', () {
    final expert = Expert(
      kind: ExpertKind.domain,
      domain: 'ios',
      spec: _minimalSpec('ios-domain', displayName: 'iOS 领域专家'),
      memory: const ExpertMemory(
        index: '# DOMAIN MEMORY',
        notes: 'L2 domain notes',
        projects: [
          ProjectRef('github.com/foo/bar', 'iOS APM SDK'),
          ProjectRef('github.com/x/y', 'iOS networking'),
        ],
      ),
      meta: const ExpertMeta(
        source: 'opensource',
        retention: 'experience-only',
        version: 1,
        learnedProjectIds: ['github.com/foo/bar', 'github.com/x/y'],
      ),
    );

    test('renders domain-notes.md and projects.md', () {
      final artifacts = adapter.render(expert);
      final paths = artifacts.map((a) => a.relativePath).toSet();

      expect(paths, contains('memory/domain-notes.md'));
      expect(paths, contains('memory/projects.md'));
      // Domain experts must NOT emit project-notes.md
      expect(paths, isNot(contains('memory/project-notes.md')));
    });

    test('memory/domain-notes.md contains expert.memory.notes', () {
      final artifacts = adapter.render(expert);
      final notes = artifacts
          .firstWhere((a) => a.relativePath == 'memory/domain-notes.md');
      expect(notes.content, 'L2 domain notes');
    });

    test('memory/projects.md lists all ProjectRef entries', () {
      final artifacts = adapter.render(expert);
      final projects =
          artifacts.firstWhere((a) => a.relativePath == 'memory/projects.md');
      expect(projects.content, contains('github.com/foo/bar'));
      expect(projects.content, contains('iOS APM SDK'));
      expect(projects.content, contains('github.com/x/y'));
      expect(projects.content, contains('iOS networking'));
    });

    test('domain expert still renders common files', () {
      final artifacts = adapter.render(expert);
      final paths = artifacts.map((a) => a.relativePath).toSet();
      expect(paths, contains('expert.json'));
      expect(paths, contains('IDENTITY.md'));
      expect(paths, contains('COMPETENCE.md'));
      expect(paths, contains('memory/MEMORY.md'));
    });
  });

  group('ExpertPoolAdapter — empty solved/playbooks emit README templates', () {
    final expert = Expert(
      kind: ExpertKind.project,
      spec: _minimalSpec('empty'),
      memory: const ExpertMemory(),
      meta: const ExpertMeta(projectId: 'pid'),
    );

    test('empty solved → memory/solved/README.md with isMemory true', () {
      final artifacts = adapter.render(expert);
      final paths = artifacts.map((a) => a.relativePath).toSet();
      expect(paths, contains('memory/solved/README.md'));

      final readme = artifacts
          .firstWhere((a) => a.relativePath == 'memory/solved/README.md');
      expect(readme.isMemory, isTrue);
      expect(readme.content, contains('Solved'));
    });

    test('empty playbooks → memory/playbooks/README.md with isMemory true', () {
      final artifacts = adapter.render(expert);
      final paths = artifacts.map((a) => a.relativePath).toSet();
      expect(paths, contains('memory/playbooks/README.md'));

      final readme = artifacts
          .firstWhere((a) => a.relativePath == 'memory/playbooks/README.md');
      expect(readme.isMemory, isTrue);
      expect(readme.content, contains('Playbooks'));
    });
  });
}

AgentSpec _minimalSpec(String name, {String displayName = 'D'}) {
  return AgentSpec(
    name: name,
    displayName: displayName,
    repos: const [],
    role: '',
    coordinates: '',
    moduleStructure: '',
    keyFiles: const [],
    dataflow: '',
    memoryConvention: '',
    conventions: const [],
  );
}
