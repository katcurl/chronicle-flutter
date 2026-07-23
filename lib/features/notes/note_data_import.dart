import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../vault/vault_models.dart';
import 'note_table_syntax.dart';
import 'scientific_reference_syntax.dart';

class NoteDataImportFile {
  const NoteDataImportFile({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;

  String get extension => p.extension(name).toLowerCase();
  bool get isTabular => NoteDataImport.isTabularFileName(name);
  bool get isImage => NoteDataImport.isImageFileName(name);
}

enum NoteDataImportMode { tableWithSource, attachmentBundle }

class NoteDataImportPlan {
  const NoteDataImportPlan({
    required this.mode,
    required this.title,
    required this.showImagePreviews,
  });

  final NoteDataImportMode mode;
  final String title;
  final bool showImagePreviews;
}

class NoteDataImportAttachment {
  const NoteDataImportAttachment({
    required this.sourceName,
    required this.result,
  });

  final String sourceName;
  final AttachmentImportResult result;

  String get linkMarkdown {
    final markdown = result.markdown;
    if (result.isImage && markdown.startsWith('![')) {
      return markdown.substring(1);
    }
    return markdown;
  }
}

class NoteDataImport {
  const NoteDataImport._();

  static const int maxFiles = 24;
  static const int maxFileBytes = 100 * 1024 * 1024;
  static const int maxTotalBytes = 120 * 1024 * 1024;
  static const int maxTableTextBytes = 1024 * 1024;
  static const Set<String> _tabularExtensions = <String>{'.csv', '.tsv'};
  static const Set<String> _imageExtensions = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
    '.tif',
    '.tiff',
  };

  static bool isTabularFileName(String name) {
    return _tabularExtensions.contains(p.extension(name).toLowerCase());
  }

  static bool isImageFileName(String name) {
    return _imageExtensions.contains(p.extension(name).toLowerCase());
  }

  static String defaultTitle(List<NoteDataImportFile> files) {
    if (files.length == 1) {
      final base = p.basenameWithoutExtension(files.single.name).trim();
      return base.isEmpty ? 'Импортированные данные' : base;
    }
    return 'Набор данных';
  }

  static ClipboardTableData parseTableFile(NoteDataImportFile file) {
    if (!file.isTabular) {
      return const ClipboardTableData(rows: <List<String>>[]);
    }
    final bytes = file.bytes.length > maxTableTextBytes
        ? Uint8List.sublistView(file.bytes, 0, maxTableTextBytes)
        : file.bytes;
    return NoteTableSyntax.parseClipboard(decodeText(bytes));
  }

  static String decodeText(Uint8List bytes) {
    if (bytes.isEmpty) {
      return '';
    }
    var start = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf) {
      start = 3;
    }
    return utf8.decode(bytes.sublist(start), allowMalformed: true);
  }

  static NoteTableModel tableModelFor({
    required NoteDataImportFile file,
    required Set<String> existingObjectKeys,
  }) {
    final parsed = parseTableFile(file);
    if (parsed.isEmpty || parsed.rows.first.length < 2) {
      throw const FormatException(
        'В файле не удалось найти таблицу минимум с двумя столбцами.',
      );
    }
    final headers = parsed.rows.first;
    final rows = parsed.rows.length > 1
        ? parsed.rows.skip(1).toList()
        : <List<String>>[List<String>.filled(headers.length, '')];
    final rawBase = p.basenameWithoutExtension(file.name);
    final normalizedBase = ScientificReferenceSyntax.normalizeId(rawBase);
    var candidate = normalizedBase;
    var suffix = 2;
    while (existingObjectKeys.contains(
      '${ScientificObjectType.table.name}:$candidate',
    )) {
      final suffixText = '-$suffix';
      final baseLength = 80 - suffixText.length;
      final prefix = normalizedBase.length > baseLength
          ? normalizedBase.substring(0, baseLength)
          : normalizedBase;
      candidate = '$prefix$suffixText';
      suffix += 1;
    }
    return NoteTableModel(
      id: candidate,
      caption: rawBase.trim(),
      headers: headers,
      rows: rows,
    );
  }

  static String buildTableImportMarkdown({
    required String title,
    required NoteTableModel table,
    required NoteDataImportAttachment source,
  }) {
    final safeTitle = _safeTitle(title);
    return <String>[
      if (safeTitle.isNotEmpty) '## $safeTitle',
      table.toMarkdown(),
      '',
      '**Исходный файл:** ${source.linkMarkdown}',
    ].join('\n');
  }

  static String buildAttachmentBundleMarkdown({
    required String title,
    required List<NoteDataImportAttachment> attachments,
    required bool showImagePreviews,
  }) {
    final safeTitle = _safeTitle(title);
    final images = <NoteDataImportAttachment>[];
    final files = <NoteDataImportAttachment>[];
    for (final attachment in attachments) {
      if (attachment.result.isImage && showImagePreviews) {
        images.add(attachment);
      } else {
        files.add(attachment);
      }
    }
    final lines = <String>[
      if (safeTitle.isNotEmpty) '## $safeTitle',
    ];
    if (images.isNotEmpty) {
      if (lines.isNotEmpty) {
        lines.add('');
      }
      lines.add('### Изображения');
      lines.add('');
      for (final image in images) {
        lines.add(image.result.markdown);
        lines.add('');
      }
    }
    if (files.isNotEmpty) {
      if (lines.isNotEmpty && lines.last.isNotEmpty) {
        lines.add('');
      }
      lines.add('### Файлы');
      lines.add('');
      for (final file in files) {
        lines.add('- ${file.linkMarkdown}');
      }
    }
    return lines.join('\n').trim();
  }

  static String fileSizeLabel(int bytes) {
    if (bytes < 1024) {
      return '$bytes Б';
    }
    final kib = bytes / 1024;
    if (kib < 1024) {
      return '${kib.toStringAsFixed(kib < 10 ? 1 : 0)} КБ';
    }
    final mib = kib / 1024;
    return '${mib.toStringAsFixed(mib < 10 ? 1 : 0)} МБ';
  }

  static String _safeTitle(String value) {
    return value.trim().replaceAll(RegExp(r'[\r\n]+'), ' ');
  }
}
