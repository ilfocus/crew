// crew_core/test/expert/project_id_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:test/test.dart';

void main() {
  group('deriveProjectId — SSH vs HTTPS equivalence', () {
    test('git@github.com:Foo/Bar.git and https://github.com/foo/bar produce same id', () {
      final sshId = deriveProjectId(
        gitRemoteUrl: 'git@github.com:Foo/Bar.git',
        path: '/some/irrelevant/path',
      );
      final httpsId = deriveProjectId(
        gitRemoteUrl: 'https://github.com/foo/bar',
        path: '/another/irrelevant/path',
      );
      expect(sshId, 'github.com/foo/bar');
      expect(httpsId, 'github.com/foo/bar');
      expect(sshId, httpsId);
    });

    test('https://github.com/foo/bar.git strips .git suffix', () {
      final id = deriveProjectId(
        gitRemoteUrl: 'https://github.com/foo/bar.git',
        path: '/whatever',
      );
      expect(id, 'github.com/foo/bar');
    });

    test('git@github.com:Foo/Bar.git strips .git suffix and lowercases', () {
      final id = deriveProjectId(
        gitRemoteUrl: 'git@github.com:Foo/Bar.git',
        path: '/whatever',
      );
      expect(id, 'github.com/foo/bar');
    });
  });

  group('deriveProjectId — case insensitivity', () {
    test('host/owner/repo are lowercased for SSH', () {
      final id = deriveProjectId(
        gitRemoteUrl: 'git@GitHub.COM:MyOrg/MyRepo.git',
        path: '/x',
      );
      expect(id, 'github.com/myorg/myrepo');
    });

    test('host/owner/repo are lowercased for HTTPS', () {
      final id = deriveProjectId(
        gitRemoteUrl: 'https://GitHub.COM/MyOrg/MyRepo.git',
        path: '/x',
      );
      expect(id, 'github.com/myorg/myrepo');
    });

    test('HTTPS without .git suffix works', () {
      final id = deriveProjectId(
        gitRemoteUrl: 'https://github.com/foo/bar',
        path: '/x',
      );
      expect(id, 'github.com/foo/bar');
    });

    test('HTTP scheme also supported', () {
      final id = deriveProjectId(
        gitRemoteUrl: 'http://github.com/foo/bar.git',
        path: '/x',
      );
      expect(id, 'github.com/foo/bar');
    });

    test('SSH and HTTPS produce identical id for same repo different case', () {
      final sshId = deriveProjectId(
        gitRemoteUrl: 'git@github.com:FOO/BAR.git',
        path: '/x',
      );
      final httpsId = deriveProjectId(
        gitRemoteUrl: 'https://github.com/foo/bar',
        path: '/x',
      );
      expect(sshId, httpsId);
      expect(sshId, 'github.com/foo/bar');
    });
  });

  group('deriveProjectId — no URL falls back to path hash', () {
    test('null URL → FNV-1a hex of path', () {
      final id = deriveProjectId(
        gitRemoteUrl: null,
        path: '/Users/qiwang/project/crew',
      );
      // 32-bit hex string, 8 chars, lowercase
      expect(id.length, 8);
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(id), isTrue);
    });

    test('empty URL string → FNV-1a hex of path', () {
      final idNull = deriveProjectId(
        gitRemoteUrl: null,
        path: '/Users/qiwang/project/crew',
      );
      final idEmpty = deriveProjectId(
        gitRemoteUrl: '',
        path: '/Users/qiwang/project/crew',
      );
      expect(idEmpty, idNull);
    });

    test('whitespace-only URL → FNV-1a hex of path', () {
      final idNull = deriveProjectId(
        gitRemoteUrl: null,
        path: '/Users/qiwang/project/crew',
      );
      final idWs = deriveProjectId(
        gitRemoteUrl: '   ',
        path: '/Users/qiwang/project/crew',
      );
      expect(idWs, idNull);
    });

    test('same path → same id (stable across calls)', () {
      const path = '/Users/qiwang/project/crew';
      final id1 = deriveProjectId(gitRemoteUrl: null, path: path);
      final id2 = deriveProjectId(gitRemoteUrl: null, path: path);
      final id3 = deriveProjectId(gitRemoteUrl: null, path: path);
      expect(id1, id2);
      expect(id2, id3);
    });

    test('different paths → different ids', () {
      final idA = deriveProjectId(gitRemoteUrl: null, path: '/path/A');
      final idB = deriveProjectId(gitRemoteUrl: null, path: '/path/B');
      expect(idA, isNot(idB));
    });

    test('URL takes precedence over path hash', () {
      final idWithUrl = deriveProjectId(
        gitRemoteUrl: 'https://github.com/foo/bar',
        path: '/some/path',
      );
      final idNoUrl = deriveProjectId(
        gitRemoteUrl: null,
        path: '/some/path',
      );
      expect(idWithUrl, 'github.com/foo/bar');
      expect(idWithUrl, isNot(idNoUrl));
    });

    test('non-git URL falls back to path hash', () {
      // A URL that is neither SSH nor http(s) should fall back to hashing the path.
      final idFallback = deriveProjectId(
        gitRemoteUrl: 'not-a-git-url',
        path: '/some/path',
      );
      final idNoUrl = deriveProjectId(
        gitRemoteUrl: null,
        path: '/some/path',
      );
      expect(idFallback, idNoUrl);
    });

    test('known FNV-1a vector — empty string', () {
      // FNV-1a of empty string is the offset basis: 0x811c9dc5.
      final id = deriveProjectId(gitRemoteUrl: null, path: '');
      expect(id, '811c9dc5');
    });

    test('known FNV-1a vector — "a"', () {
      // FNV-1a of single byte 'a' (0x61):
      // hash = 0x811c9dc5 ^ 0x61 = 0x811c9da4
      // hash = (0x811c9da4 * 0x01000193) & 0xFFFFFFFF = 0xe40c292c
      final id = deriveProjectId(gitRemoteUrl: null, path: 'a');
      expect(id, 'e40c292c');
    });

    test('known FNV-1a vector — "foobar"', () {
      // Reference FNV-1a 32-bit of "foobar" is 0xbf9cf968.
      final id = deriveProjectId(gitRemoteUrl: null, path: 'foobar');
      expect(id, 'bf9cf968');
    });
  });
}
