// crew_core/lib/src/models/agent_template.dart
class AgentTemplate {
  final String id;
  final int version;
  final String defaultName;
  final String displayName;
  final String role;
  final String probePrompt;
  final List<String> matchGlobs;
  final String personality;
  final List<String> principles;

  const AgentTemplate({
    required this.id,
    required this.version,
    required this.defaultName,
    required this.displayName,
    required this.role,
    required this.probePrompt,
    required this.matchGlobs,
    this.personality = '',
    this.principles = const [],
  });

  String get ref => '$id@$version';
}
