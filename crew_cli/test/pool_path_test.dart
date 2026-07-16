// crew_cli/test/pool_path_test.dart
import 'dart:io';

import 'package:crew_cli/src/pool_path.dart';
import 'package:test/test.dart';

void main() {
  group('defaultPoolDir', () {
    test('returns <home>/.crew/experts', () {
      final dir = defaultPoolDir();
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.';
      expect(dir.path, '$home/.crew/experts');
    });
  });

  group('resolvePoolDir', () {
    test('returns override directory when provided', () {
      final dir = resolvePoolDir('/custom/pool');
      expect(dir.path, '/custom/pool');
    });

    test('returns default when override is null', () {
      final dir = resolvePoolDir(null);
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.';
      expect(dir.path, '$home/.crew/experts');
    });

    test('returns default when override is empty string', () {
      final dir = resolvePoolDir('');
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.';
      expect(dir.path, '$home/.crew/experts');
    });
  });
}
