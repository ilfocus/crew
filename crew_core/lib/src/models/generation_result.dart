// crew_core/lib/src/models/generation_result.dart
import 'agent_spec.dart';
import 'crew_config.dart';
import 'team_profile.dart';

class GenerationResult {
  final CrewConfig config;
  final List<AgentSpec> specs;
  final TeamProfile team;
  const GenerationResult({
    required this.config,
    required this.specs,
    required this.team,
  });
}
