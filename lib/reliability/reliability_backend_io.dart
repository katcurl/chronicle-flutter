import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class ReliabilityBackend {
  Future<String?> saveDiagnosticReport({
    required String fileName,
    required String contents,
  }) {
    return FilePicker.saveFile(
      dialogTitle: 'Сохранить диагностический отчёт Chronicle',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(contents)),
    );
  }
}
