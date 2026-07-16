// crew_cli/bin/crew.dart
import 'dart:io';

import 'package:args/args.dart';
import 'package:crew_cli/crew_cli.dart';

ArgParser _publishParser() {
  return ArgParser()
    ..addOption('agent', abbr: 'a', help: 'Workspace agent name to publish')
    ..addOption('workspace', abbr: 'w', help: 'Workspace root path')
    ..addOption('retention',
        abbr: 'r',
        defaultsTo: 'experience-only',
        allowed: ['full', 'experience-only', 'none'],
        help: 'Memory retention level')
    ..addOption('source',
        abbr: 's',
        defaultsTo: 'private',
        allowed: ['opensource', 'private'],
        help: 'Project source')
    ..addOption('domain', abbr: 'd', help: 'Domain to merge into (optional)')
    ..addOption('pool', abbr: 'p', help: 'Expert pool directory override')
    ..addOption('tool',
        defaultsTo: 'claude',
        allowed: ['claude', 'codex'],
        help: 'CLI tool used for domain distill')
    ..addOption('version',
        abbr: 'v',
        defaultsTo: '1',
        help: 'Expert version number (integer)');
}

ArgParser _useExpertParser() {
  return ArgParser()
    ..addOption('domain', abbr: 'd', help: 'Domain expert to instantiate')
    ..addOption('into', abbr: 'i', help: 'Target workspace path')
    ..addOption('agent', abbr: 'a', help: 'New agent name in target workspace')
    ..addMultiOption('repo', abbr: 'r', help: 'Repos for the new agent')
    ..addOption('pool', abbr: 'p', help: 'Expert pool directory override');
}

ArgParser _listExpertsParser() {
  return ArgParser()
    ..addOption('pool', abbr: 'p', help: 'Expert pool directory override');
}

Future<void> _runPublish(List<String> rest) async {
  final parser = _publishParser();
  final args = parser.parse(rest);
  final agent = args['agent'] as String?;
  final workspace = args['workspace'] as String?;
  if (agent == null || workspace == null) {
    stderr.writeln('publish requires --agent and --workspace');
    exit(1);
  }
  final result = await runPublish(
    options: PublishOptions(
      agentName: agent,
      workspacePath: workspace,
      retention: args['retention'] as String,
      source: args['source'] as String,
      domain: args['domain'] as String?,
      poolDir: resolvePoolDir(args['pool'] as String?),
      cliTool: args['tool'] as String,
      version: int.parse(args['version'] as String),
    ),
  );
  if (result.projectId == null) {
    stdout.writeln('Publish skipped (retention: none).');
  } else {
    stdout.writeln('Published project expert: ${result.projectId}');
    stdout.writeln('  pool: ${result.poolPath}');
    if (result.domainMerged != null) {
      stdout.writeln('  merged into domain: ${result.domainMerged}');
    }
  }
}

Future<void> _runUseExpert(List<String> rest) async {
  final parser = _useExpertParser();
  final args = parser.parse(rest);
  final domain = args['domain'] as String?;
  final into = args['into'] as String?;
  final agent = args['agent'] as String?;
  if (domain == null || into == null || agent == null) {
    stderr.writeln('use-expert requires --domain, --into, and --agent');
    exit(1);
  }
  final result = await runUseExpert(
    options: UseExpertOptions(
      domain: domain,
      intoPath: into,
      agentName: agent,
      repos: (args['repo'] as List).cast<String>(),
      poolDir: resolvePoolDir(args['pool'] as String?),
    ),
  );
  stdout.writeln('Instantiated agent "$agent" from domain "$domain".');
  stdout.writeln('Wrote ${result.writtenPaths.length} files:');
  for (final p in result.writtenPaths) {
    stdout.writeln('  $p');
  }
}

Future<void> _runListExperts(List<String> rest) async {
  final parser = _listExpertsParser();
  final args = parser.parse(rest);
  await runListExperts(poolDir: resolvePoolDir(args['pool'] as String?));
}

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln('Usage: crew <command> [options]');
    stderr.writeln('Commands: publish, use-expert, list-experts');
    exit(1);
  }

  final command = arguments.first;
  final rest = arguments.sublist(1);

  try {
    switch (command) {
      case 'publish':
        await _runPublish(rest);
        break;
      case 'use-expert':
        await _runUseExpert(rest);
        break;
      case 'list-experts':
        await _runListExperts(rest);
        break;
      case '--help':
      case '-h':
      case 'help':
        stderr.writeln('Usage: crew <command> [options]');
        stderr.writeln('Commands: publish, use-expert, list-experts');
        exit(0);
        break;
      default:
        stderr.writeln('Unknown command: $command');
        stderr.writeln('Commands: publish, use-expert, list-experts');
        exit(1);
    }
  } on ArgumentError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
