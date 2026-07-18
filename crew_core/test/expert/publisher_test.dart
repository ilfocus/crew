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
    test('produces AgentCore + ProjectCompetence; projectId from URL', () {
      final out = publishProject(
        agentId: 'ios-lin',
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar.git',
        workspacePath: '/workspace/ios',
        version: 3,
      );

      expect(out, isNotNull);
      // core
      expect(out!.core.id, 'ios-lin');
      expect(out.core.name, 'ios');
      expect(out.core.displayName, '小i');
      expect(out.core.role, 'iOS 开发工程师');
      expect(out.core.personality, '严谨');
      expect(out.core.principles, ['不引入未测试依赖']);

      // project
      expect(out.project.projectId, 'github.com/foo/bar');
      expect(out.project.repos, ['~/bm_app/ios']);
      expect(out.project.coordinates, '路径 ~/bm_app/ios');
      expect(out.project.keyFiles.length, 1);
      expect(out.project.keyFiles.first.path, 'Core/BMApm.swift:279');
      expect(out.project.techStack, ['Swift', 'SwiftUI']);
      expect(out.project.sdks, ['SensorsSDK']);
      expect(out.project.difficulties, ['线程安全']);
      expect(out.project.github, 'https://github.com/foo/bar.git');
      expect(out.project.source, 'opensource');
      expect(out.project.retention, 'full');

      // L1 memory preserved
      expect(out.project.notes, 'L1 notes with /Users/bm/app/ios path');
      expect(out.project.solved.length, 1);
      expect(out.project.solved.first.path, 'solved/x.md');
      expect(out.project.playbooks.length, 1);
    });

    test('private source leaves project.github empty', () {
      final out = publishProject(
        agentId: 'ios-lin',
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'private',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 1,
      );
      expect(out, isNotNull);
      expect(out!.project.source, 'private');
      expect(out.project.github, '');
      // projectId still derived from URL
      expect(out.project.projectId, 'github.com/foo/bar');
    });

    test('falls back to path hash when no gitRemoteUrl', () {
      final out = publishProject(
        agentId: 'ios-lin',
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'private',
        workspacePath: '/Users/qiwang/project/crew',
        version: 1,
      );
      expect(out, isNotNull);
      expect(out!.project.projectId.length, 8);
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(out.project.projectId), isTrue);
    });

    test('core.id equals agentId (individual, not role)', () {
      final out = publishProject(
        agentId: 'ios-lin',
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 1,
      );
      expect(out, isNotNull);
      expect(out!.core.id, 'ios-lin');
      // role ≠ id (multiple agents can share role)
      expect(out.core.role, 'iOS 开发工程师');
      expect(out.core.id, isNot(out.core.role));
    });

    test('mapping divides fields correctly: personality→core, keyFiles→project',
        () {
      final out = publishProject(
        agentId: 'ios-lin',
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 1,
      );
      expect(out, isNotNull);

      // personality/principles 落 core，不在 project
      expect(out!.core.personality, '严谨');
      expect(out.core.principles, ['不引入未测试依赖']);

      // keyFiles/coordinates/repos 落 project，不在 core
      expect(out.project.keyFiles.length, 1);
      expect(out.project.coordinates, '路径 ~/bm_app/ios');
      expect(out.project.repos, ['~/bm_app/ios']);
      // core 里没有这些字段
      expect(out.core.toJson().containsKey('keyFiles'), isFalse);
      expect(out.core.toJson().containsKey('coordinates'), isFalse);
    });
  });

  group('publishProject — experience-only retention', () {
    test('clears keyFiles/coordinates/repos/solved; preserves transferable', () {
      final out = publishProject(
        agentId: 'ios-lin',
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'experience-only',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 2,
      );

      expect(out, isNotNull);
      expect(out!.project.retention, 'experience-only');

      // L1 specifics cleared in project
      expect(out.project.keyFiles, isEmpty);
      expect(out.project.coordinates, '');
      expect(out.project.repos, isEmpty);
      expect(out.project.solved, isEmpty);

      // core 的 personality/principles 仍保留（可迁移）
      expect(out.core.personality, '严谨');
      expect(out.core.principles, ['不引入未测试依赖']);

      // project 的可迁移字段保留
      expect(out.project.techStack, ['Swift', 'SwiftUI']);
      expect(out.project.sdks, ['SensorsSDK']);
      expect(out.project.difficulties, ['线程安全']);

      // playbooks 保留但 content 路径脱敏
      expect(out.project.playbooks.length, 1);
      expect(out.project.playbooks.first.path, 'playbooks/y.md');

      // notes 路径脱敏
      expect(out.project.notes.contains('/Users/bm/app/ios'), isFalse);
      expect(out.project.notes.contains('‹path›'), isTrue);
    });

    test('redacts paths in notes and playbooks for experience-only', () {
      final out = publishProject(
        agentId: 'ios-lin',
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'experience-only',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 2,
      );

      expect(out, isNotNull);
      expect(out!.project.notes.contains('/Users/bm/app/ios'), isFalse);
      expect(out.project.notes.contains('‹path›'), isTrue);
      expect(out.project.playbooks.first.content.contains('foo/bar.dart:12'),
          isFalse);
      expect(out.project.playbooks.first.content.contains('‹path›'), isTrue);
    });
  });

  group('publishProject — none retention', () {
    test('returns null', () {
      final out = publishProject(
        agentId: 'ios-lin',
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'none',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 1,
      );
      expect(out, isNull);
    });
  });

  group('publishProject — domains inverse index', () {
    test('new project starts with empty domains list', () {
      final out = publishProject(
        agentId: 'ios-lin',
        spec: _fullSpec(),
        workspaceMemory: _fullMemory(),
        retention: 'full',
        source: 'opensource',
        gitRemoteUrl: 'https://github.com/foo/bar',
        workspacePath: '/workspace/ios',
        version: 1,
      );
      // 新发布的 project.domains 是空——由后续 mergeIntoDomain 时填
      expect(out, isNotNull);
      expect(out!.project.domains, isEmpty);
    });
  });
}
