// crew_core/lib/src/models/expert_summary.dart
import 'expert.dart';

/// A lightweight summary entry for [ExpertPool] listings.
class ExpertSummary {
  final ExpertKind kind;

  /// projectId for project experts; domain name for domain experts.
  final String id;
  final String displayName;
  final int version;

  const ExpertSummary({
    required this.kind,
    required this.id,
    required this.displayName,
    required this.version,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpertSummary &&
          kind == other.kind &&
          id == other.id &&
          displayName == other.displayName &&
          version == other.version;

  @override
  int get hashCode => Object.hash(kind, id, displayName, version);

  @override
  String toString() => 'ExpertSummary($kind, $id, v$version)';
}
