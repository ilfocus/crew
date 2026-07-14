// crew_gui/lib/services/directory_picker.dart
import 'package:file_picker/file_picker.dart';

abstract class DirectoryPicker {
  Future<String?> pick();
}

class FilePickerDirectoryPicker implements DirectoryPicker {
  @override
  Future<String?> pick() => FilePicker.platform.getDirectoryPath();
}

class FakeDirectoryPicker implements DirectoryPicker {
  String? next;
  FakeDirectoryPicker(this.next);
  @override
  Future<String?> pick() async => next;
}
