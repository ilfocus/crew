// crew_core/test/analysis/repo_analyzer_test.dart
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
}
