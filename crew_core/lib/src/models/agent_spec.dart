// crew_core/lib/src/models/agent_spec.dart
class KeyFile {
  final String path;
  final String purpose;
  const KeyFile(this.path, this.purpose);

  Map<String, dynamic> toJson() => {'path': path, 'purpose': purpose};

  factory KeyFile.fromJson(Map<String, dynamic> j) =>
      KeyFile(j['path'].toString(), j['purpose']?.toString() ?? '');
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

  // --- 新增字段（全部带默认值，向后兼容） ---
  final String personality;       // 人格/性格
  final List<String> principles;  // 判断标准/品味/质量红线
  final List<String> techStack;   // 技术栈
  final List<String> sdks;        // 用到的 SDK/三方库
  final List<String> difficulties; // 重难点清单
  final String source;            // 项目来源：opensource | private
  final String github;            // 开源仓库地址

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
    this.personality = '',
    this.principles = const [],
    this.techStack = const [],
    this.sdks = const [],
    this.difficulties = const [],
    this.source = 'private',
    this.github = '',
  });

  /// 中性序列化：将来 expert.json 的核心搬运单元
  Map<String, dynamic> toJson() => {
        'name': name,
        'displayName': displayName,
        'repos': repos,
        'role': role,
        'coordinates': coordinates,
        'moduleStructure': moduleStructure,
        'keyFiles': keyFiles.map((k) => k.toJson()).toList(),
        'dataflow': dataflow,
        'memoryConvention': memoryConvention,
        'conventions': conventions,
        'personality': personality,
        'principles': principles,
        'techStack': techStack,
        'sdks': sdks,
        'difficulties': difficulties,
        'source': source,
        'github': github,
      };

  factory AgentSpec.fromJson(Map<String, dynamic> j) {
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return AgentSpec(
      name: j['name'].toString(),
      displayName: j['displayName'].toString(),
      repos: strList(j['repos']),
      role: j['role']?.toString() ?? '',
      coordinates: j['coordinates']?.toString() ?? '',
      moduleStructure: j['moduleStructure']?.toString() ?? '',
      keyFiles: ((j['keyFiles'] as List?) ?? const [])
          .map((e) => KeyFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      dataflow: j['dataflow']?.toString() ?? '',
      memoryConvention: j['memoryConvention']?.toString() ?? '',
      conventions: strList(j['conventions']),
      personality: j['personality']?.toString() ?? '',
      principles: strList(j['principles']),
      techStack: strList(j['techStack']),
      sdks: strList(j['sdks']),
      difficulties: strList(j['difficulties']),
      source: j['source']?.toString() ?? 'private',
      github: j['github']?.toString() ?? '',
    );
  }

  /// copyWith：P2 专家池 merge 也会用；全字段可选，不传则保留原值。
  AgentSpec copyWith({
    String? name,
    String? displayName,
    List<String>? repos,
    String? role,
    String? coordinates,
    String? moduleStructure,
    List<KeyFile>? keyFiles,
    String? dataflow,
    String? memoryConvention,
    List<String>? conventions,
    String? personality,
    List<String>? principles,
    List<String>? techStack,
    List<String>? sdks,
    List<String>? difficulties,
    String? source,
    String? github,
  }) {
    return AgentSpec(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      repos: repos ?? this.repos,
      role: role ?? this.role,
      coordinates: coordinates ?? this.coordinates,
      moduleStructure: moduleStructure ?? this.moduleStructure,
      keyFiles: keyFiles ?? this.keyFiles,
      dataflow: dataflow ?? this.dataflow,
      memoryConvention: memoryConvention ?? this.memoryConvention,
      conventions: conventions ?? this.conventions,
      personality: personality ?? this.personality,
      principles: principles ?? this.principles,
      techStack: techStack ?? this.techStack,
      sdks: sdks ?? this.sdks,
      difficulties: difficulties ?? this.difficulties,
      source: source ?? this.source,
      github: github ?? this.github,
    );
  }

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
      personality: json['personality']?.toString() ?? '',
      principles: strList(json['principles']),
      techStack: strList(json['techStack']),
      sdks: strList(json['sdks']),
      difficulties: strList(json['difficulties']),
      source: json['source']?.toString() ?? 'private',
      github: json['github']?.toString() ?? '',
    );
  }
}
