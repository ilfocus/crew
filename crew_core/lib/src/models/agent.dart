// crew_core/lib/src/models/agent.dart
const String kAllRepos = '<all>';

class Agent {
  final String name;
  final String templateRef;
  final List<String> repos;

  const Agent({
    required this.name,
    required this.templateRef,
    required this.repos,
  });

  bool get isAllRepos => repos.contains(kAllRepos);

  Map<String, dynamic> toJson() =>
      {'name': name, 'template': templateRef, 'repos': repos};

  factory Agent.fromJson(Map<dynamic, dynamic> json) => Agent(
        name: json['name'] as String,
        templateRef: json['template'] as String,
        repos:
            (json['repos'] as List).map((e) => e.toString()).toList(),
      );
}
