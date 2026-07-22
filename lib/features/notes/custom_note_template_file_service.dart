import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'custom_note_template_store.dart';
import 'note_templates.dart';

class CustomNoteTemplateFileService {
  const CustomNoteTemplateFileService();

  Future<String?> exportTemplates(List<NoteTemplate> templates) async {
    if (templates.isEmpty) {
      throw StateError('Нет шаблонов для экспорта.');
    }
    final payload = CustomNoteTemplateStore.encodeExportBundle(templates);
    return FilePicker.saveFile(
      dialogTitle: 'Экспорт шаблонов Chronicle',
      fileName: 'chronicle-note-templates.json',
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      bytes: Uint8List.fromList(utf8.encode(payload)),
      lockParentWindow: true,
    );
  }

  Future<List<NoteTemplate>?> importTemplates() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Импорт шаблонов Chronicle',
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      lockParentWindow: true,
    );
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: false);
    return CustomNoteTemplateStore.decodeImportBundle(text);
  }
}
