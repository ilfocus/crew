// crew_core/test/expert/publisher_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

AgentSpec _fullSpec() => const AgentSpec(
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

ExpertMemory _fullMemory() => const ExpertMemory(
      index: '# MEMORY',
      notes: 'L1 notes with /Users/bm/app/ios path',
      solved: [MemoryEntry('solved/x.md', 'fix X at Core/Foo.swift:42')],
      playbooks: [MemoryEntry('playbooks/y.md', 'use foo/bar.dart:12 carefully')],
    );

void main() {
  group('publishProject — full retention', () {
    test('produces complete spec + memory; projectId from URL; github in meta',
        () {
      final expert = publishProject(
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar.git',
        workspacePath: '/workspace/ios',
        version: 3,
      );

      expect(expert, isNotNull);
      expect(expert!.kind, ExpertKind.project);

      // spec preserved entirely
      expect(expert.spec.name, 'ios');
      expect(expert.spec.repos, ['~/bm_app/ios']);
      expect(expert.spec.coordinates, '路径 ~/bm_app/ios');
      expect(expert.spec.keyFiles.length, 1);
      expect(expert.spec.keyFiles.first.path, 'Core/BMApm.swift:279');
      expect(expert.spec.personality, '严谨');
      expect(expert.spec.techStack, ['Swift', 'SwiftUI']);
      expect(expert.spec.difficulties, ['线程安全']);

      // memory preserved entirely
      expect(expert.memory.index, '# MEMORY');
      expect(expert.memory.notes, 'L1 notes with /Users/bm/app/ios path');
      expect(expert.memory.solved.length, 1);
      expect(expert.memory.solved.first.path, 'solved/x.md');
      expect(expert.memory.playbooks.length, 1);

      // meta
      expect(expert.meta.retention, 'full');
      expect(expert.meta.source, 'opensource');
      expect(expert.meta.github, 'https://github.com/foo/bar.git');
      expect(expert.meta.version, 3);
      expect(expert.meta.projectId, 'github.com/foo/bar');
    });

    test('projectId matches deriveProjectId result', () {
      final expert = publishProject(
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'opensource',
        gitRemoteUrl: 'git@github.com:Foo/Bar.git',
        workspacePath: '/workspace/ios',
        version: 1,
      );
      final expected = deriveProjectId(
        gitRemoteUrl: 'git@github.com:Foo/Bar.git',
        path: '/workspace/ios',
      );
      expect(expert!.meta.projectId, expected);
      expect(expert.meta.projectId, 'github.com/foo/bar');
    });

    test('private source leaves meta.github empty', () {
      final expert = publishProject(
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'private',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 1,
      );
      expect(expert!.meta.source, 'private');
      expect(expert.meta.github, '');
      // projectId still derived from URL since it was passed
      expect(expert.meta.projectId, 'github.com/foo/bar');
    });

    test('falls back to path hash when no gitRemoteUrl', () {
      final expert = publishProject(
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'private',
        workspacePath: '/Users/qiwang/project/crew',
        version: 1,
      );
      expect(expert!.meta.projectId.length, 8);
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(expert.meta.projectId), isTrue);
    });
  });

  group('publishProject — experience-only retention', () {
    test('clears keyFiles/coordinates/solved but preserves transferable fields',
        () {
      final expert = publishProject(
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'experience-only',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 2,
      );

      expect(expert, isNotNull);
      expect(expert!.meta.retention, 'experience-only');

      // L1 specifics cleared
      expect(expert.spec.keyFiles, isEmpty);
      expect(expert.spec.coordinates, '');
      expect(expert.spec.repos, isEmpty);
      expect(expert.memory.solved, isEmpty);

      // Transferable fields preserved
      expect(expert.spec.personality, '严谨');
      expect(expert.spec.principles, ['不引入未测试依赖']);
      expect(expert.spec.techStack, ['Swift', 'SwiftUI']);
      expect(expert.spec.sdks, ['SensorsSDK']);
      expect(expert.spec.difficulties, ['线程安全']);

      // Playbooks (already abstract) preserved
      expect(expert.memory.playbooks.length, 1);
      expect(expert.memory.playbooks.first.path, 'playbooks/y.md');

      // notes redacted for experience-only
      expect(expert.memory.notes, 'L1 notes with ‹path› path');
    });

    test('redacts paths in notes and playbooks for experience-only', () {
      final expert = publishProject(
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'experience-only',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 2,
      );

      expect(expert, isNotNull);

      // notes: /Users/bm/app/ios should be redacted
      expect(expert!.memory.notes.contains('/Users/bm/app/ios'), isFalse);
      expect(expert.memory.notes.contains('‹path›'), isTrue);

      // playbooks: foo/bar.dart:12 should be redacted
      expect(expert.memory.playbooks.length, 1);
      expect(
          expert.memory.playbooks.first.content.contains('foo/bar.dart:12'),
          isFalse);
      expect(expert.memory.playbooks.first.content.contains('‹path›'), isTrue);
      // playbook path (filename) preserved
      expect(expert.memory.playbooks.first.path, 'playbooks/y.md');
    });

    test('full retention preserves paths in notes and playbooks', () {
      final expert = publishProject(
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'private',
        workspacePath: '/workspace/ios',
        version: 1,
      );

      expect(expert, isNotNull);
      // full retention — no redaction
      expect(expert!.memory.notes.contains('/Users/bm/app/ios'), isTrue);
      expect(expert.memory.playbooks.first.content.contains('foo/bar.dart:12'),
          isTrue);
    });
  });

  group('publishProject — none retention', () {
    test('returns null', () {
      final expert = publishProject(
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'none',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 1,
      );
      expect(expert, isNull);
    });
  });
}
