// crew_core/lib/src/models/crew_config.dart
import 'package:yaml/yaml.dart';
import 'agent.dart';
import 'repo.dart';

class CrewConfig {
  final int version;
  final String name;
  final String createdAt;
  final List<Repo> repos;
  final List<String> targets;
  final String runner;
  final List<Agent> agents;

  const CrewConfig({
    required this.version,
    required this.name,
    required this.createdAt,
    required this.repos,
    required this.targets,
    required this.runner,
    required this.agents,
  });

  String toYaml() {
    final b = StringBuffer();
    b.writeln('version: $version');
    b.writeln('name: $name');
    b.writeln('createdAt: $createdAt');
    b.writeln('repos:');
    for (final r in repos) {
      b.writeln('  - path: ${r.path}');
    }
    b.writeln('targets: [${targets.join(', ')}]');
    b.writeln('runner: $runner');
    b.writeln('agents:');
    for (final a in agents) {
      b.writeln('  - name: ${a.name}');
      b.writeln('    template: ${a.templateRef}');
      b.writeln('    repos: [${a.repos.join(', ')}]');
    }
    return b.toString();
  }

  factory CrewConfig.fromYaml(String yamlText) {
    final doc = loadYaml(yamlText) as YamlMap;
    return CrewConfig(
      version: doc['version'] as int,
      name: doc['name'] as String,
      createdAt: doc['createdAt'].toString(),
      repos: (doc['repos'] as YamlList)
          .map((e) => Repo((e as YamlMap)['path'] as String))
          .toList(),
      targets: (doc['targets'] as YamlList)
          .map((e) => e.toString())
          .toList(),
      runner: doc['runner'] as String,
      agents: (doc['agents'] as YamlList)
          .map((e) => Agent.fromJson(e as YamlMap))
          .toList(),
    );
  }
}
