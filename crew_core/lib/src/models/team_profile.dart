// crew_core/lib/src/models/team_profile.dart
import 'agent_spec.dart';

class TeamProfile {
  final String name;
  final List<AgentSpec> members;
  const TeamProfile({required this.name, required this.members});
}
