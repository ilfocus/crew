// crew_gui/lib/app_scaffold.dart
import 'package:flutter/material.dart';
import 'services/directory_picker.dart';
import 'services/project_store.dart';
import 'services/template_repository.dart';
import 'services/workspace_opener.dart';
import 'state/generation_controller.dart';
import 'state/wizard_controller.dart';
import 'ui/home_page.dart';
import 'ui/wizard/wizard_page.dart';

class AppScaffold extends StatefulWidget {
  final ProjectStore store;
  final TemplateRepository templates;
  final DirectoryPicker picker;
  final WorkspaceOpener opener;
  final GenerationController Function() generationFactory;
  const AppScaffold({
    super.key,
    required this.store,
    required this.templates,
    required this.picker,
    required this.opener,
    required this.generationFactory,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  Widget? _wizard;

  void _startNew() {
    setState(() {
      _wizard = WizardPage(
        wizard: WizardController(),
        templates: widget.templates,
        picker: widget.picker,
        generation: widget.generationFactory(),
        opener: widget.opener,
        store: widget.store,
        onDone: () => setState(() => _wizard = null),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _wizard ??
        HomePage(
          store: widget.store,
          onNew: _startNew,
          onOpen: (e) => widget.opener.openFolder(e.path),
        );
  }
}
