import 'package:file_picker/file_picker.dart';

import 'note_data_import.dart';

Future<List<NoteDataImportFile>?> pickNoteDataImportFiles() async {
  final result = await FilePicker.pickFiles(
    dialogTitle: 'Импортировать данные в заметку',
    type: FileType.any,
    allowMultiple: true,
    lockParentWindow: true,
  );
  if (result == null) {
    return null;
  }
  if (result.files.isEmpty) {
    return const <NoteDataImportFile>[];
  }
  if (result.files.length > NoteDataImport.maxFiles) {
    throw FormatException(
      'За один раз можно импортировать не больше '
      '${NoteDataImport.maxFiles} файлов.',
    );
  }
  for (final file in result.files) {
    if (file.size > NoteDataImport.maxFileBytes) {
      throw FormatException(
        'Файл «${file.name}» больше 100 МБ.',
      );
    }
  }
  final declaredTotal = result.files.fold<int>(
    0,
    (sum, file) => sum + file.size,
  );
  if (declaredTotal > NoteDataImport.maxTotalBytes) {
    throw const FormatException(
      'Общий размер выбранных файлов больше 120 МБ.',
    );
  }

  final files = <NoteDataImportFile>[];
  var actualTotal = 0;
  for (final file in result.files) {
    final bytes = await file.readAsBytes();
    if (bytes.length > NoteDataImport.maxFileBytes) {
      throw FormatException(
        'Файл «${file.name}» больше 100 МБ.',
      );
    }
    actualTotal += bytes.length;
    if (actualTotal > NoteDataImport.maxTotalBytes) {
      throw const FormatException(
        'Общий размер выбранных файлов больше 120 МБ.',
      );
    }
    files.add(NoteDataImportFile(name: file.name, bytes: bytes));
  }
  return files;
}
