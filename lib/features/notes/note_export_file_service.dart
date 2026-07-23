import 'package:file_picker/file_picker.dart';

import 'note_export.dart';

class NoteExportFileService {
  const NoteExportFileService();

  Future<String?> save(ChronicleExportPayload payload) {
    return FilePicker.saveFile(
      dialogTitle: 'Сохранить экспорт Chronicle',
      fileName: payload.fileName,
      type: FileType.custom,
      allowedExtensions: <String>[payload.extension],
      bytes: payload.bytes,
      lockParentWindow: true,
    );
  }
}
