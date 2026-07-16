// crew_cli/lib/src/pool_path.dart
import 'dart:io';

/// Default pool directory: ~/.crew/experts
Directory defaultPoolDir() {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  return Directory('$home/.crew/experts');
}

/// Resolve pool directory, allowing override.
Directory resolvePoolDir(String? override) {
  if (override != null && override.isNotEmpty) {
    return Directory(override);
  }
  return defaultPoolDir();
}
