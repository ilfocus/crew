// crew_gui/test/state/wizard_controller_select_test.dart
import 'package:crew_core/crew_core.dart';
import 'package:crew_gui/state/wizard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('addDirectory dedupes and ignores empty', () {
    final c = WizardController();
    c.addDirectory('/a');
    c.addDirectory('/a');
    c.addDirectory('');
    expect(c.directories, ['/a']);
  });

  test('toggleTemplate selects and unselects by ref', () {
    final c = WizardController();
    final ios = kBuiltinTemplates.firstWhere((t) => t.id == 'ios-dev');
    expect(c.isSelected(ios), isFalse);
    c.toggleTemplate(ios);
    expect(c.isSelected(ios), isTrue);
    c.toggleTemplate(ios);
    expect(c.isSelected(ios), isFalse);
  });

  test('notifies listeners on changes', () {
    final c = WizardController();
    var n = 0;
    c.addListener(() => n++);
    c.addDirectory('/a');
    c.toggleTemplate(kBuiltinTemplates.first);
    expect(n, 2);
  });
}
