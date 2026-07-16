// crew_core/lib/src/expert/project_id.dart

/// Normalize git remote URL or fall back to path hash.
///
/// - `git@github.com:Foo/Bar.git` → `github.com/foo/bar`
/// - `https://github.com/foo/bar` → `github.com/foo/bar`
/// - `https://github.com/foo/bar.git` → `github.com/foo/bar`
/// - No URL → FNV-1a hash of absolute path (32-bit hex string).
///
/// Same path → same id; different paths → different ids.
String deriveProjectId({String? gitRemoteUrl, required String path}) {
  final url = gitRemoteUrl?.trim() ?? '';
  if (url.isNotEmpty) {
    final normalized = _normalizeGitUrl(url);
    if (normalized != null) return normalized;
  }
  return _fnv1aHex(path);
}

/// Normalize SSH or HTTPS git URLs to `host/owner/repo` (lowercase).
/// Returns null if the URL doesn't look like a git remote.
String? _normalizeGitUrl(String url) {
  var s = url;

  // SSH form: git@host:owner/repo.git
  if (s.startsWith('git@')) {
    s = s.substring('git@'.length); // host:owner/repo.git
    s = s.replaceFirst(':', '/'); // host/owner/repo.git
    if (s.endsWith('.git')) s = s.substring(0, s.length - 4);
    return s.toLowerCase();
  }

  // HTTPS form: https://host/owner/repo.git or http://host/owner/repo
  for (final scheme in const ['https://', 'http://']) {
    if (s.startsWith(scheme)) {
      s = s.substring(scheme.length); // host/owner/repo.git
      if (s.endsWith('.git')) s = s.substring(0, s.length - 4);
      // Strip a trailing slash if any.
      while (s.endsWith('/')) {
        s = s.substring(0, s.length - 1);
      }
      return s.toLowerCase();
    }
  }

  return null;
}

/// 32-bit FNV-1a hash, returned as lowercase hex string.
String _fnv1aHex(String input) {
  const int offsetBasis = 0x811c9dc5;
  const int prime = 0x01000193;
  const int mask = 0xFFFFFFFF; // keep 32-bit
  var hash = offsetBasis;
  for (final byte in input.codeUnits) {
    hash = (hash ^ byte) & mask;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
