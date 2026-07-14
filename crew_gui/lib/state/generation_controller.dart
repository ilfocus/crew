// crew_gui/lib/state/generation_controller.dart
import 'package:crew_core/crew_core.dart';
import 'package:flutter/foundation.dart';

enum GenStatus { idle, generating, planned, emitting, done, error }

class GenerationController extends ChangeNotifier {
  final GenerationPipeline Function(CrewConfig) pipelineFactory;
  GenerationController({required this.pipelineFactory});

  GenStatus status = GenStatus.idle;
  GenerationResult? result;
  WritePlan? plan;
  String? error;

  GenerationPipeline? _pipeline;

  Future<void> generateAndPlan(String root, CrewConfig config) async {
    status = GenStatus.generating;
    error = null;
    notifyListeners();
    try {
      final pipeline = pipelineFactory(config);
      final r = await pipeline.generate(config);
      final p = pipeline.planWrites(root, r);
      _pipeline = pipeline;
      result = r;
      plan = p;
      status = GenStatus.planned;
    } catch (e) {
      error = e.toString();
      status = GenStatus.error;
    }
    notifyListeners();
  }

  Future<void> confirmAndEmit(String root) async {
    if (_pipeline == null || result == null) return;
    status = GenStatus.emitting;
    notifyListeners();
    try {
      await _pipeline!.emit(root, result!);
      status = GenStatus.done;
    } catch (e) {
      error = e.toString();
      status = GenStatus.error;
    }
    notifyListeners();
  }
}
