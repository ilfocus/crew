// crew_core/lib/src/models/agent_spec.dart
class KeyFile {
  final String path;
  final String purpose;
  const KeyFile(this.path, this.purpose);
}

class AgentSpec {
  final String name;
  final String displayName;
  final List<String> repos;
  final String role;
  final String coordinates;
  final String moduleStructure;
  final List<KeyFile> keyFiles;
  final String dataflow;
  final String memoryConvention;
  final List<String> conventions;

  const AgentSpec({
    required this.name,
    required this.displayName,
    required this.repos,
    required this.role,
    required this.coordinates,
    required this.moduleStructure,
    required this.keyFiles,
    required this.dataflow,
    required this.memoryConvention,
    required this.conventions,
  });

  factory AgentSpec.fromProbeJson(
    Map<String, dynamic> json, {
    required String name,
    required String displayName,
    required List<String> repos,
  }) {
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    final keyFiles = ((json['keyFiles'] as List?) ?? const [])
        .map((e) => KeyFile(
              (e as Map)['path'].toString(),
              e['purpose']?.toString() ?? '',
            ))
        .toList();
    return AgentSpec(
      name: name,
      displayName: displayName,
      repos: repos,
      role: json['role']?.toString() ?? '',
      coordinates: json['coordinates']?.toString() ?? '',
      moduleStructure: json['moduleStructure']?.toString() ?? '',
      keyFiles: keyFiles,
      dataflow: json['dataflow']?.toString() ?? '',
      memoryConvention: json['memoryConvention']?.toString() ?? '',
      conventions: strList(json['conventions']),
    );
  }
}
