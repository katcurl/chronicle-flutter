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
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Импорт шаблонов Chronicle',
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      allowMultiple: false,
      withData: true,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw StateError('Не удалось прочитать выбранный файл.');
    }
    final text = utf8.decode(bytes, allowMalformed: false);
    return CustomNoteTemplateStore.decodeImportBundle(text);
  }
}
