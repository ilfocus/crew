// crew_gui/lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'app_scaffold.dart';
import 'services/directory_picker.dart';
import 'services/pipeline_factory.dart';
import 'services/project_store.dart';
import 'services/template_repository.dart';
import 'services/workspace_opener.dart';
import 'state/generation_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final store = ProjectStore(File(p.join(dir.path, 'projects.json')));
  final templates = TemplateRepository(File(p.join(dir.path, 'templates.json')));
  await templates.loadCustom();

  runApp(CrewApp(
    home: AppScaffold(
      store: store,
      templates: templates,
      picker: FilePickerDirectoryPicker(),
      opener: ProcessWorkspaceOpener(),
      generationFactory: () => GenerationController(
        pipelineFactory: (config) => buildPipeline(
          config,
          resolve: templates.resolve,
        ),
      ),
    ),
  ));
}
