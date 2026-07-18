// crew_core/test/analysis/repo_analyzer_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory iosDir;
  late Directory pyDir;

  setUp(() {
    iosDir = Directory.systemTemp.createTempSync('ios_repo');
    File('${iosDir.path}/Podfile').writeAsStringSync('');
    File('${iosDir.path}/App.xcworkspace').writeAsStringSync('');
    pyDir = Directory.systemTemp.createTempSync('py_repo');
    File('${pyDir.path}/requirements.txt').writeAsStringSync('');
  });

  tearDown(() {
    iosDir.deleteSync(recursive: true);
    pyDir.deleteSync(recursive: true);
  });

  test('suggests ios template for the ios repo, python for py repo', () {
    final analyzer = RepoAnalyzer();
    final candidates = analyzer.suggest(kBuiltinTemplates, [iosDir.path, pyDir.path]);

    AssignmentCandidate best(String repo) => candidates
        .where((c) => c.repoPath == repo)
        .reduce((a, b) => a.score >= b.score ? a : b);

    expect(best(iosDir.path).templateId, 'ios-dev');
    expect(best(pyDir.path).templateId, 'python');
  });

  test('no candidates for an empty repo', () {
    final empty = Directory.systemTemp.createTempSync('empty_repo');
    addTearDown(() => empty.deleteSync(recursive: true));
    final candidates = RepoAnalyzer().suggest(kBuiltinTemplates, [empty.path]);
    expect(candidates.where((c) => c.repoPath == empty.path), isEmpty);
  });

  test('gitRemoteUrl parses origin URL from .git/config', () {
    final repo = Directory.systemTemp.createTempSync('git_repo');
    addTearDown(() => repo.deleteSync(recursive: true));
    final gitDir = Directory('${repo.path}/.git');
    gitDir.createSync();
    File('${gitDir.path}/config').writeAsStringSync(
      '[core]\n'
      '\trepositoryformatversion = 0\n'
      '[remote "origin"]\n'
      '\turl = https://github.com/foo/bar.git\n'
      '\tfetch = +refs/heads/*:refs/remotes/origin/*\n'
      '[branch "main"]\n'
      '\tremote = origin\n'
      '\tmerge = refs/heads/main\n');
    expect(RepoAnalyzer().gitRemoteUrl(repo.path), 'https://github.com/foo/bar.git');
  });

  test('gitRemoteUrl returns null when no .git/config', () {
    final repo = Directory.systemTemp.createTempSync('no_git');
    addTearDown(() => repo.deleteSync(recursive: true));
    expect(RepoAnalyzer().gitRemoteUrl(repo.path), isNull);
  });

  test('gitRemoteUrl returns null when no remote origin', () {
    final repo = Directory.systemTemp.createTempSync('no_remote');
    addTearDown(() => repo.deleteSync(recursive: true));
    final gitDir = Directory('${repo.path}/.git');
    gitDir.createSync();
    File('${gitDir.path}/config').writeAsStringSync('[core]\n\tbare = false\n');
    expect(RepoAnalyzer().gitRemoteUrl(repo.path), isNull);
  });

  group('Glob matching', () {
    test('vite.config.* matches vite.config.ts', () {
      final repo = Directory.systemTemp.createTempSync('vite_repo');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/package.json').writeAsStringSync('{}');
      File('${repo.path}/vite.config.ts').writeAsStringSync('');
      File('${repo.path}/tsconfig.json').writeAsStringSync('{}');
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      final fe = cs.firstWhere((c) =>
          c.templateId == 'frontend' && c.repoPath == repo.path);
      expect(fe.score, greaterThanOrEqualTo(3));
      expect(fe.signals, containsAll(['package.json', 'vite.config.ts', 'tsconfig.json']));
    });

    test('multiple *.swift files collapse into a single signal', () {
      final repo = Directory.systemTemp.createTempSync('multi_swift');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/App.swift').writeAsStringSync('');
      File('${repo.path}/Utils.swift').writeAsStringSync('');
      File('${repo.path}/Podfile').writeAsStringSync('');
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      final ios = cs.firstWhere((c) =>
          c.templateId == 'ios-dev' && c.repoPath == repo.path);
      expect(ios.signals, contains('Podfile'));
      expect(ios.signals, contains('*.swift ×2'));
    });

    test('templates with empty matchGlobs (pm) never produce candidates', () {
      final repo = Directory.systemTemp.createTempSync('pm_repo');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/Podfile').writeAsStringSync('');
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      expect(cs.where((c) => c.templateId == 'pm'), isEmpty);
    });
  });

  group('Deep signals — config file content', () {
    test('frontend: detects React from package.json', () {
      final repo = Directory.systemTemp.createTempSync('fe_react');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/package.json').writeAsStringSync(jsonEncode({
        'name': 'demo',
        'dependencies': {
          'react': '^18.0.0',
          'react-dom': '^18.0.0',
          'next': '^14.0.0',
        },
        'devDependencies': {
          'typescript': '^5.0.0',
        },
      }));
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      final fe = cs.firstWhere((c) =>
          c.templateId == 'frontend' && c.repoPath == repo.path);
      expect(fe.signals, containsAll(['React', 'Next.js', 'TypeScript']));
    });

    test('frontend: detects Vue + Nuxt without TypeScript', () {
      final repo = Directory.systemTemp.createTempSync('fe_vue');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/package.json').writeAsStringSync(jsonEncode({
        'dependencies': {'vue': '^3.0.0', 'nuxt': '^3.0.0'},
      }));
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      final fe = cs.firstWhere((c) =>
          c.templateId == 'frontend' && c.repoPath == repo.path);
      expect(fe.signals, containsAll(['Vue', 'Nuxt']));
      expect(fe.signals, isNot(contains('TypeScript')));
    });

    test('backend: extracts Go module path', () {
      final repo = Directory.systemTemp.createTempSync('go_repo');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/go.mod').writeAsStringSync(
          'module github.com/acme/foo\n\ngo 1.21\n');
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      final be = cs.firstWhere((c) =>
          c.templateId == 'backend' && c.repoPath == repo.path);
      expect(be.signals, contains('module: github.com/acme/foo'));
    });

    test('backend: extracts Maven groupId from pom.xml', () {
      final repo = Directory.systemTemp.createTempSync('maven_repo');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/pom.xml').writeAsStringSync(
          '<?xml version="1.0"?>\n<project>\n  <groupId>com.acme</groupId>\n  <artifactId>foo</artifactId>\n</project>');
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      final be = cs.firstWhere((c) =>
          c.templateId == 'backend' && c.repoPath == repo.path);
      expect(be.signals, contains('groupId: com.acme'));
    });

    test('ios: extracts platform version and target names from Podfile', () {
      final repo = Directory.systemTemp.createTempSync('ios_pod');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/Podfile').writeAsStringSync(
          "platform :ios, '15.0'\ntarget 'App' do\n  use_frameworks!\nend\ntarget 'AppTests' do\nend\n");
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      final ios = cs.firstWhere((c) =>
          c.templateId == 'ios-dev' && c.repoPath == repo.path);
      expect(ios.signals, contains('iOS 15.0'));
      expect(ios.signals, contains('targets: App, AppTests'));
    });

    test('android: extracts applicationId from build.gradle', () {
      final repo = Directory.systemTemp.createTempSync('android_gradle');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/build.gradle').writeAsStringSync(
          "android {\n  namespace 'com.acme.app'\n  defaultConfig {\n    applicationId 'com.acme.app'\n  }\n}\n");
      File('${repo.path}/settings.gradle').writeAsStringSync('');
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      final an = cs.firstWhere((c) =>
          c.templateId == 'android-dev' && c.repoPath == repo.path);
      expect(an.signals, contains('applicationId: com.acme.app'));
      expect(an.signals, contains('namespace: com.acme.app'));
    });

    test('python: detects Django/FastAPI from requirements.txt', () {
      final repo = Directory.systemTemp.createTempSync('py_django');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/requirements.txt').writeAsStringSync(
          '# main\nDjango>=4.0\nfastapi==0.110.0\nrequests\nunused-pkg\n');
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      final py = cs.firstWhere((c) =>
          c.templateId == 'python' && c.repoPath == repo.path);
      expect(py.signals, containsAll(['Django', 'FastAPI', 'requests']));
    });

    test('malformed package.json does not crash, falls back to glob signals', () {
      final repo = Directory.systemTemp.createTempSync('fe_bad_json');
      addTearDown(() => repo.deleteSync(recursive: true));
      File('${repo.path}/package.json').writeAsStringSync('{ not valid json');
      final cs = RepoAnalyzer().suggest(kBuiltinTemplates, [repo.path]);
      // 仅靠 matchGlobs 命中 package.json，深度扫描静默失败
      final fe = cs.firstWhere((c) =>
          c.templateId == 'frontend' && c.repoPath == repo.path);
      expect(fe.signals, contains('package.json'));
    });
  });

  group('Auto-detect (full template set)', () {
    test('multi-repo workspace: each repo gets its best-matching template', () {
      final tmp = Directory.systemTemp.createTempSync('multi_ws');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final ios = Directory('${tmp.path}/ios')..createSync();
      File('${ios.path}/Podfile').writeAsStringSync(
          "platform :ios, '16.0'\ntarget 'App' do\nend\n");
      final fe = Directory('${tmp.path}/web')..createSync();
      File('${fe.path}/package.json').writeAsStringSync(jsonEncode({
        'dependencies': {'react': '^18.0.0'},
      }));
      final go = Directory('${tmp.path}/api')..createSync();
      File('${go.path}/go.mod').writeAsStringSync(
          'module github.com/acme/api\n\ngo 1.22\n');

      final cs = RepoAnalyzer().suggest(
          kBuiltinTemplates, [ios.path, fe.path, go.path]);

      // 三个 repo 都有命中
      final reposHit = cs.map((c) => c.repoPath).toSet();
      expect(reposHit, containsAll([ios.path, fe.path, go.path]));

      // iOS repo 的最佳匹配是 ios-dev
      final iosBest = cs
          .where((c) => c.repoPath == ios.path)
          .reduce((a, b) => a.score >= b.score ? a : b);
      expect(iosBest.templateId, 'ios-dev');
      // 前端 repo 的最佳匹配是 frontend
      final feBest = cs
          .where((c) => c.repoPath == fe.path)
          .reduce((a, b) => a.score >= b.score ? a : b);
      expect(feBest.templateId, 'frontend');
      // Go repo 的最佳匹配是 backend
      final goBest = cs
          .where((c) => c.repoPath == go.path)
          .reduce((a, b) => a.score >= b.score ? a : b);
      expect(goBest.templateId, 'backend');
    });
  });
}
