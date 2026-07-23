import 'dart:convert';
import 'dart:typed_data';

import 'package:markdown/markdown.dart' as markdown;
import 'package:path/path.dart' as path;

import '../../models/app_models.dart';
import 'note_document.dart';
import 'note_image_syntax.dart';
import 'note_wiki_link_syntax.dart';

enum ChronicleExportFormat { markdown, html, docx, pdf, portableArchive }

class ChronicleExportPayload {
  const ChronicleExportPayload({
    required this.fileName,
    required this.extension,
    required this.bytes,
    required this.assetCount,
    required this.missingAttachments,
  });

  final String fileName;
  final String extension;
  final Uint8List bytes;
  final int assetCount;
  final List<String> missingAttachments;
}

class NoteExportComposer {
  NoteExportComposer({required this.readAttachment});

  static const int maxPortableArchiveBytes = 240 * 1024 * 1024;

  final Future<Uint8List?> Function(String relativePath) readAttachment;

  Future<ChronicleExportPayload> exportNote({
    required Note note,
    required String projectTitle,
    required ChronicleExportFormat format,
  }) async {
    final baseName = safeFileStem(note.title, fallback: 'note');
    final rawContent = NoteDocument.parse(note.body).content;

    if (format == ChronicleExportFormat.markdown) {
      final rendered = _renderPortableNoteMarkdown(
        note,
        projectTitle: projectTitle,
        content: rawContent,
      );
      return ChronicleExportPayload(
        fileName: '$baseName.md',
        extension: 'md',
        bytes: Uint8List.fromList(utf8.encode(rendered)),
        assetCount: 0,
        missingAttachments: const <String>[],
      );
    }

    final assetSet = await _loadAssets(<String>[rawContent]);
    if (format == ChronicleExportFormat.html) {
      final replacements = <String, String>{};
      for (final reference in _attachmentReferences(rawContent)) {
        final asset = assetSet.bySourcePath[reference.sourcePath];
        if (asset == null) {
          continue;
        }
        replacements[reference.rawTarget] = asset.dataUri;
      }
      final html = _renderNoteHtml(
        note,
        projectTitle: projectTitle,
        content: _replaceTargets(rawContent, replacements),
      );
      return ChronicleExportPayload(
        fileName: '$baseName.html',
        extension: 'html',
        bytes: Uint8List.fromList(utf8.encode(html)),
        assetCount: assetSet.assets.length,
        missingAttachments: assetSet.missing,
      );
    }

    final assetNames = _assignArchiveAssetNames(assetSet.assets);
    final archiveTargetMap = <String, String>{};
    for (final reference in _attachmentReferences(rawContent)) {
      final exportedPath = assetNames[reference.sourcePath];
      if (exportedPath != null) {
        archiveTargetMap[reference.rawTarget] = _encodeRelativePath(exportedPath);
      }
    }
    final archiveContent = _replaceTargets(rawContent, archiveTargetMap);
    final portableMarkdown = _renderPortableNoteMarkdown(
      note,
      projectTitle: projectTitle,
      content: archiveContent,
    );
    final html = _renderNoteHtml(
      note,
      projectTitle: projectTitle,
      content: archiveContent,
    );
    final archive = StoredZipArchiveBuilder()
      ..addText('$baseName.md', portableMarkdown)
      ..addText('$baseName.html', html)
      ..addText(
        'manifest.json',
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'format': 'chronicle-note-export',
          'version': 1,
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
          'note': <String, Object?>{
            'id': note.id,
            'title': note.title,
            'projectId': note.projectId,
            'projectTitle': projectTitle,
            'updatedAt': note.updatedAt.toUtc().toIso8601String(),
          },
          'files': <String>['$baseName.md', '$baseName.html'],
          'attachments': (assetNames.values.toList()..sort()),
          'missingAttachments': assetSet.missing,
        }),
      );
    for (final asset in assetSet.assets) {
      final exportPath = assetNames[asset.sourcePath];
      if (exportPath != null) {
        archive.addBytes(exportPath, asset.bytes);
      }
    }
    final bytes = archive.build();
    _validateArchiveSize(bytes.length);
    return ChronicleExportPayload(
      fileName: '$baseName-export.zip',
      extension: 'zip',
      bytes: bytes,
      assetCount: assetSet.assets.length,
      missingAttachments: assetSet.missing,
    );
  }

  Future<ChronicleExportPayload> exportProject({
    required Project project,
    required List<Note> notes,
    required List<WorkTask> tasks,
    required ChronicleExportFormat format,
  }) async {
    final baseName = safeFileStem(project.title, fallback: 'project');
    final orderedNotes = List<Note>.from(notes)
      ..sort((left, right) => left.title.compareTo(right.title));
    final orderedTasks = List<WorkTask>.from(tasks)
      ..sort((left, right) {
        final order = left.sortOrder.compareTo(right.sortOrder);
        return order != 0 ? order : left.title.compareTo(right.title);
      });
    final noteFileNames = _noteFileNames(orderedNotes);
    final noteById = <String, Note>{for (final note in orderedNotes) note.id: note};
    final noteByTitle = <String, Note>{
      for (final note in orderedNotes) note.title.trim().toLowerCase(): note,
    };

    String? resolveCombined(NoteWikiTarget target) {
      final resolved = _resolveWikiTarget(target, noteById, noteByTitle);
      return resolved == null ? null : '#note-${_anchorId(resolved.id)}';
    }

    String? resolveArchive(NoteWikiTarget target) {
      final resolved = _resolveWikiTarget(target, noteById, noteByTitle);
      return resolved == null ? null : noteFileNames[resolved.id];
    }

    if (format == ChronicleExportFormat.markdown) {
      final combined = _renderProjectMarkdown(
        project,
        orderedNotes,
        orderedTasks,
        wikiResolver: resolveCombined,
      );
      return ChronicleExportPayload(
        fileName: '$baseName.md',
        extension: 'md',
        bytes: Uint8List.fromList(utf8.encode(combined)),
        assetCount: 0,
        missingAttachments: const <String>[],
      );
    }

    final contents = <String>[
      for (final note in orderedNotes) NoteDocument.parse(note.body).content,
    ];
    final assetSet = await _loadAssets(contents);

    if (format == ChronicleExportFormat.html) {
      final dataTargets = <String, String>{};
      for (final content in contents) {
        for (final reference in _attachmentReferences(content)) {
          final asset = assetSet.bySourcePath[reference.sourcePath];
          if (asset != null) {
            dataTargets[reference.rawTarget] = asset.dataUri;
          }
        }
      }
      final html = _renderProjectHtml(
        project,
        orderedNotes,
        orderedTasks,
        targetReplacements: dataTargets,
        wikiResolver: resolveCombined,
      );
      return ChronicleExportPayload(
        fileName: '$baseName.html',
        extension: 'html',
        bytes: Uint8List.fromList(utf8.encode(html)),
        assetCount: assetSet.assets.length,
        missingAttachments: assetSet.missing,
      );
    }

    final assetNames = _assignArchiveAssetNames(assetSet.assets);
    final archive = StoredZipArchiveBuilder();
    final readme = _renderProjectReadme(
      project,
      orderedNotes,
      orderedTasks,
      noteFileNames,
    );
    archive.addText('README.md', readme);

    final htmlTargets = <String, String>{};
    for (final content in contents) {
      for (final reference in _attachmentReferences(content)) {
        final exportPath = assetNames[reference.sourcePath];
        if (exportPath != null) {
          htmlTargets[reference.rawTarget] = _encodeRelativePath(exportPath);
        }
      }
    }
    archive.addText(
      'README.html',
      _renderProjectHtml(
        project,
        orderedNotes,
        orderedTasks,
        targetReplacements: htmlTargets,
        wikiResolver: resolveCombined,
      ),
    );

    for (final note in orderedNotes) {
      final content = NoteDocument.parse(note.body).content;
      final replacements = <String, String>{};
      for (final reference in _attachmentReferences(content)) {
        final exportedPath = assetNames[reference.sourcePath];
        if (exportedPath != null) {
          replacements[reference.rawTarget] =
              '../${_encodeRelativePath(exportedPath)}';
        }
      }
      final replacedContent = _replaceTargets(content, replacements);
      final linked = _convertWikiLinks(
        replacedContent,
        (target) {
          final destination = resolveArchive(target);
          return destination == null ? null : _encodeRelativePath(destination);
        },
      );
      final htmlLinked = _convertWikiLinks(
        replacedContent,
        (target) {
          final destination = resolveArchive(target);
          if (destination == null) {
            return null;
          }
          final htmlName =
              '${path.basenameWithoutExtension(destination)}.html';
          return _encodeRelativePath(htmlName);
        },
      );
      archive.addText(
        'notes/${noteFileNames[note.id]}',
        _renderPortableNoteMarkdown(
          note,
          projectTitle: project.title,
          content: linked,
        ),
      );
      archive.addText(
        'notes/${path.basenameWithoutExtension(noteFileNames[note.id]!)}.html',
        _renderNoteHtml(
          note,
          projectTitle: project.title,
          content: htmlLinked,
        ),
      );
    }
    for (final asset in assetSet.assets) {
      final exportPath = assetNames[asset.sourcePath];
      if (exportPath != null) {
        archive.addBytes(exportPath, asset.bytes);
      }
    }
    archive.addText(
      'manifest.json',
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'format': 'chronicle-project-export',
        'version': 1,
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'project': project.toJson(),
        'noteCount': orderedNotes.length,
        'taskCount': orderedTasks.length,
        'notes': <Map<String, Object?>>[
          for (final note in orderedNotes)
            <String, Object?>{
              'id': note.id,
              'title': note.title,
              'file': 'notes/${noteFileNames[note.id]}',
            },
        ],
        'attachments': (assetNames.values.toList()..sort()),
        'missingAttachments': assetSet.missing,
      }),
    );
    final bytes = archive.build();
    _validateArchiveSize(bytes.length);
    return ChronicleExportPayload(
      fileName: '$baseName-export.zip',
      extension: 'zip',
      bytes: bytes,
      assetCount: assetSet.assets.length,
      missingAttachments: assetSet.missing,
    );
  }

  Future<_LoadedAssets> _loadAssets(List<String> markdownSources) async {
    final requested = <String>{};
    for (final source in markdownSources) {
      for (final reference in _attachmentReferences(source)) {
        requested.add(reference.sourcePath);
      }
    }
    final assets = <_LoadedAsset>[];
    final missing = <String>[];
    var totalBytes = 0;
    for (final sourcePath in requested) {
      final bytes = await readAttachment(sourcePath);
      if (bytes == null) {
        missing.add(sourcePath);
        continue;
      }
      totalBytes += bytes.length;
      if (totalBytes > maxPortableArchiveBytes) {
        throw const FormatException(
          'Суммарный размер вложений для экспорта больше 240 МБ.',
        );
      }
      assets.add(
        _LoadedAsset(
          sourcePath: sourcePath,
          bytes: bytes,
          mimeType: _mimeTypeForPath(sourcePath),
        ),
      );
    }
    missing.sort();
    return _LoadedAssets(assets: assets, missing: missing);
  }

  void _validateArchiveSize(int byteLength) {
    if (byteLength > maxPortableArchiveBytes) {
      throw const FormatException(
        'Размер переносимого ZIP больше 240 МБ.',
      );
    }
  }

  static String safeFileStem(String value, {required String fallback}) {
    var normalized = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (normalized.isEmpty) {
      normalized = fallback;
    }
    if (normalized.length > 80) {
      normalized = normalized.substring(0, 80).trimRight();
    }
    return normalized;
  }

  static String _renderPortableNoteMarkdown(
    Note note, {
    required String projectTitle,
    required String content,
  }) {
    final reserved = <String>{
      'chronicle_id',
      'title',
      'project_id',
      'project_title',
      'folder',
      'type',
      'status',
      'tags',
      'pinned',
      'revision',
      'created_at',
      'updated_at',
    };
    final lines = <String>[
      '---',
      'chronicle_id: ${_yamlString(note.id)}',
      'title: ${_yamlString(note.title)}',
      'project_id: ${_yamlString(note.projectId)}',
      'project_title: ${_yamlString(projectTitle)}',
      'folder: ${_yamlString(note.folderPath)}',
      'type: ${_yamlString(note.noteType)}',
      'status: ${_yamlString(note.status)}',
      'tags: ${jsonEncode(note.tags)}',
      'pinned: ${note.pinned}',
      'revision: ${note.revision}',
      'created_at: ${_yamlString(note.createdAt.toUtc().toIso8601String())}',
      'updated_at: ${_yamlString(note.updatedAt.toUtc().toIso8601String())}',
      for (final entry in note.properties.entries)
        if (!reserved.contains(entry.key.trim().toLowerCase()) &&
            RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(entry.key.trim()))
          '${entry.key.trim()}: ${_yamlString(entry.value)}',
      '---',
      '',
      content.trimLeft(),
    ];
    return '${lines.join('\n').trimRight()}\n';
  }

  static String _renderNoteHtml(
    Note note, {
    required String projectTitle,
    required String content,
  }) {
    final prepared = _renderChronicleImages(
      _convertWikiLinks(content, (_) => null),
    );
    final body = markdown.markdownToHtml(
      prepared,
      extensionSet: markdown.ExtensionSet.gitHubFlavored,
    );
    return _htmlDocument(
      title: note.title,
      metadata: <String, String>{
        'Проект': projectTitle,
        'Тип': note.noteType,
        'Статус': note.status,
        if (note.folderPath.trim().isNotEmpty) 'Папка': note.folderPath,
        if (note.tags.isNotEmpty) 'Теги': note.tags.join(', '),
        'Обновлено': note.updatedAt.toLocal().toIso8601String(),
      },
      body: body,
    );
  }

  static void _writeProjectResearchSummary(
    StringBuffer buffer,
    Project project,
  ) {
    final hasSummary =
        project.researchGoal.trim().isNotEmpty ||
        project.researchQuestions.isNotEmpty ||
        project.knownFindings.isNotEmpty ||
        project.openChecks.isNotEmpty;
    if (!hasSummary) return;
    buffer
      ..writeln('## Исследовательская рамка')
      ..writeln();
    if (project.researchGoal.trim().isNotEmpty) {
      buffer
        ..writeln('### Цель')
        ..writeln()
        ..writeln(project.researchGoal.trim())
        ..writeln();
    }
    if (project.researchQuestions.isNotEmpty) {
      buffer
        ..writeln('### Исследовательские вопросы')
        ..writeln();
      for (final question in project.researchQuestions) {
        buffer.writeln('- $question');
      }
      buffer.writeln();
    }
    if (project.knownFindings.isNotEmpty) {
      buffer
        ..writeln('### Уже известно')
        ..writeln();
      for (final finding in project.knownFindings) {
        buffer.writeln('- $finding');
      }
      buffer.writeln();
    }
    if (project.openChecks.isNotEmpty) {
      buffer
        ..writeln('### Нужно проверить')
        ..writeln();
      for (final check in project.openChecks) {
        buffer.writeln('- $check');
      }
      buffer.writeln();
    }
  }

  static String _renderProjectMarkdown(
    Project project,
    List<Note> notes,
    List<WorkTask> tasks, {
    required String? Function(NoteWikiTarget target) wikiResolver,
  }) {
    final buffer = StringBuffer()
      ..writeln('# ${project.emoji} ${project.title}')
      ..writeln();
    if (project.description.trim().isNotEmpty) {
      buffer
        ..writeln(project.description.trim())
        ..writeln();
    }
    _writeProjectResearchSummary(buffer, project);
    buffer
      ..writeln('## Задачи')
      ..writeln();
    if (tasks.isEmpty) {
      buffer.writeln('_Задач нет._');
    } else {
      for (final task in tasks) {
        final checked = task.status == 'done' ? 'x' : ' ';
        buffer.writeln('- [$checked] ${task.title}');
      }
    }
    buffer
      ..writeln()
      ..writeln('## Заметки')
      ..writeln();
    if (notes.isEmpty) {
      buffer.writeln('_Заметок нет._');
    }
    for (final note in notes) {
      final content = _convertWikiLinks(
        NoteDocument.parse(note.body).content,
        wikiResolver,
      );
      buffer
        ..writeln('<a id="note-${_anchorId(note.id)}"></a>')
        ..writeln()
        ..writeln('### ${note.title}')
        ..writeln()
        ..writeln(content.trim())
        ..writeln();
    }
    return '${buffer.toString().trimRight()}\n';
  }

  static String _renderProjectReadme(
    Project project,
    List<Note> notes,
    List<WorkTask> tasks,
    Map<String, String> noteFileNames,
  ) {
    final buffer = StringBuffer()
      ..writeln('# ${project.emoji} ${project.title}')
      ..writeln();
    if (project.description.trim().isNotEmpty) {
      buffer
        ..writeln(project.description.trim())
        ..writeln();
    }
    _writeProjectResearchSummary(buffer, project);
    buffer
      ..writeln('## Задачи')
      ..writeln();
    if (tasks.isEmpty) {
      buffer.writeln('_Задач нет._');
    } else {
      for (final task in tasks) {
        final checked = task.status == 'done' ? 'x' : ' ';
        buffer.writeln('- [$checked] ${task.title}');
      }
    }
    buffer
      ..writeln()
      ..writeln('## Заметки')
      ..writeln();
    if (notes.isEmpty) {
      buffer.writeln('_Заметок нет._');
    } else {
      for (final note in notes) {
        buffer.writeln(
          '- [${note.title}](notes/${_encodeRelativePath(noteFileNames[note.id]!)})',
        );
      }
    }
    return '${buffer.toString().trimRight()}\n';
  }

  static String _renderProjectHtml(
    Project project,
    List<Note> notes,
    List<WorkTask> tasks, {
    required Map<String, String> targetReplacements,
    required String? Function(NoteWikiTarget target) wikiResolver,
  }) {
    final markdownSource = _renderProjectMarkdown(
      project,
      <Note>[
        for (final note in notes)
          _copyNoteWithBody(
            note,
            _replaceTargets(
              NoteDocument.parse(note.body).content,
              targetReplacements,
            ),
          ),
      ],
      tasks,
      wikiResolver: wikiResolver,
    );
    final body = markdown.markdownToHtml(
      _renderChronicleImages(markdownSource),
      extensionSet: markdown.ExtensionSet.gitHubFlavored,
    );
    return _htmlDocument(
      title: project.title,
      metadata: <String, String>{
        'Заметок': '${notes.length}',
        'Задач': '${tasks.length}',
        'Обновлено': project.updatedAt.toLocal().toIso8601String(),
      },
      body: body,
    );
  }

  static Note _copyNoteWithBody(Note source, String content) {
    final note = Note(
      id: source.id,
      title: source.title,
      projectId: source.projectId,
      body: '',
      tags: List<String>.from(source.tags),
      status: source.status,
      folderPath: source.folderPath,
      noteType: source.noteType,
      properties: Map<String, String>.from(source.properties),
      pinned: source.pinned,
      revision: source.revision,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
      deletedAt: source.deletedAt,
    );
    note.body = NoteDocument.serialize(note, content);
    return note;
  }

  static String _htmlDocument({
    required String title,
    required Map<String, String> metadata,
    required String body,
  }) {
    final details = metadata.entries
        .map(
          (entry) =>
              '<dt>${_htmlText(entry.key)}</dt>'
              '<dd>${_htmlText(entry.value)}</dd>',
        )
        .join();
    return '''<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_htmlText(title)}</title>
<style>
:root { color-scheme: light dark; }
body { margin: 0; font: 16px/1.65 system-ui, sans-serif; background: Canvas; color: CanvasText; }
main { max-width: 940px; margin: 0 auto; padding: 40px 28px 80px; }
header { padding-bottom: 24px; border-bottom: 1px solid color-mix(in srgb, CanvasText 18%, transparent); }
h1, h2, h3 { line-height: 1.25; }
dl { display: grid; grid-template-columns: max-content 1fr; gap: 4px 18px; }
dt { font-weight: 700; }
dd { margin: 0; }
img { max-width: 100%; height: auto; }
figure { margin: 1.4em auto; }
figure.align-left { margin-left: 0; }
figure.align-right { margin-right: 0; }
figcaption { margin-top: .45em; color: color-mix(in srgb, CanvasText 70%, transparent); text-align: center; }
table { border-collapse: collapse; display: block; overflow-x: auto; }
th, td { border: 1px solid color-mix(in srgb, CanvasText 25%, transparent); padding: 6px 10px; }
pre { overflow-x: auto; padding: 14px; background: color-mix(in srgb, CanvasText 8%, Canvas); }
blockquote { margin-left: 0; padding-left: 16px; border-left: 4px solid color-mix(in srgb, CanvasText 25%, transparent); }
a { overflow-wrap: anywhere; }
</style>
</head>
<body>
<main>
<header>
<h1>${_htmlText(title)}</h1>
<dl>$details</dl>
</header>
$body
</main>
</body>
</html>
''';
  }

  static String _renderChronicleImages(String source) {
    var result = source;
    final images = NoteImageSyntax.all(source).toList().reversed;
    for (final image in images) {
      final alignment = image.presentation.alignment.name;
      final caption = image.presentation.caption.trim();
      final rendered = StringBuffer()
        ..write(
          '<figure class="align-$alignment" '
          'style="width:${image.presentation.widthPercent}%">',
        )
        ..write(
          '<img src="${_htmlAttribute(image.target)}" '
          'alt="${_htmlAttribute(image.alt)}">',
        );
      if (caption.isNotEmpty) {
        rendered.write('<figcaption>${_htmlText(caption)}</figcaption>');
      }
      rendered.write('</figure>');
      result = result.replaceRange(image.start, image.end, rendered.toString());
    }
    return result;
  }

  static Map<String, String> _noteFileNames(List<Note> notes) {
    final used = <String>{};
    final result = <String, String>{};
    for (final note in notes) {
      final base = safeFileStem(note.title, fallback: 'note');
      var candidate = '$base.md';
      var suffix = 2;
      while (!used.add(candidate.toLowerCase())) {
        candidate = '$base-$suffix.md';
        suffix += 1;
      }
      result[note.id] = candidate;
    }
    return result;
  }

  static Note? _resolveWikiTarget(
    NoteWikiTarget target,
    Map<String, Note> noteById,
    Map<String, Note> noteByTitle,
  ) {
    final exactId = target.noteId;
    if (exactId != null) {
      return noteById[exactId];
    }
    return noteByTitle[target.noteTitle.trim().toLowerCase()];
  }

  static String _convertWikiLinks(
    String source,
    String? Function(NoteWikiTarget target) resolver,
  ) {
    var result = source;
    final references = NoteWikiLinkSyntax.all(source).toList().reversed;
    for (final reference in references) {
      final target = NoteWikiTarget.parse(reference.target);
      final destination = resolver(target);
      final label = reference.visibleLabel;
      final replacement =
          destination == null
              ? label
              : '[$label](${_markdownDestination(destination)}'
                  '${reference.anchor ?? ''})';
      result = result.replaceRange(reference.start, reference.end, replacement);
    }
    return result;
  }

  static Map<String, String> _assignArchiveAssetNames(
    List<_LoadedAsset> assets,
  ) {
    final result = <String, String>{};
    final used = <String>{};
    for (final asset in assets) {
      final rawName = path.posix.basename(asset.sourcePath);
      final extension = path.extension(rawName);
      final base = safeFileStem(
        path.basenameWithoutExtension(rawName),
        fallback: 'attachment',
      ).replaceAll(' ', '-');
      var candidate = 'assets/$base$extension';
      var suffix = 2;
      while (!used.add(candidate.toLowerCase())) {
        candidate = 'assets/$base-$suffix$extension';
        suffix += 1;
      }
      result[asset.sourcePath] = candidate;
    }
    return result;
  }

  static Iterable<_AttachmentReference> _attachmentReferences(
    String source,
  ) sync* {
    final pattern = RegExp(
      r'!?\[(?:\\.|[^\]])*\]\(\s*(?:<([^>]+)>|([^\s)]+))',
      multiLine: true,
    );
    for (final match in pattern.allMatches(source)) {
      final rawTarget = match.group(1) ?? match.group(2) ?? '';
      final normalized = _normalizeAttachmentPath(rawTarget);
      if (normalized != null) {
        yield _AttachmentReference(
          rawTarget: rawTarget,
          sourcePath: normalized,
        );
      }
    }
  }

  static String? _normalizeAttachmentPath(String rawTarget) {
    var decoded = rawTarget.trim();
    try {
      decoded = Uri.decodeComponent(decoded);
    } on Object {
      // Keep the original target when malformed percent escapes are present.
    }
    decoded = decoded.replaceAll('\\', '/');
    final marker = decoded.indexOf('Attachments/');
    if (marker < 0) {
      return null;
    }
    final normalized = decoded.substring(marker).split(RegExp(r'[?#]')).first;
    final segments = normalized.split('/');
    if (segments.length < 2 ||
        segments.any((segment) => segment.isEmpty || segment == '..')) {
      return null;
    }
    return normalized;
  }

  static String _replaceTargets(
    String source,
    Map<String, String> replacements,
  ) {
    var result = source;
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static String _encodeRelativePath(String value) {
    return value
        .replaceAll('\\', '/')
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
  }

  static String _markdownDestination(String value) {
    if (value.contains(RegExp(r'\s'))) {
      return '<$value>';
    }
    return value;
  }

  static String _mimeTypeForPath(String value) {
    return switch (path.extension(value).toLowerCase()) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.svg' => 'image/svg+xml',
      '.pdf' => 'application/pdf',
      '.csv' => 'text/csv',
      '.tsv' => 'text/tab-separated-values',
      '.txt' || '.md' => 'text/plain',
      '.json' => 'application/json',
      '.zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  static String _yamlString(String value) {
    return jsonEncode(value);
  }

  static String _anchorId(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '-');
  }

  static String _htmlText(String value) {
    return const HtmlEscape().convert(value);
  }

  static String _htmlAttribute(String value) {
    return const HtmlEscape().convert(value);
  }
}

class StoredZipArchiveBuilder {
  final List<_ZipEntry> _entries = <_ZipEntry>[];

  void addText(String fileName, String content) {
    addBytes(fileName, Uint8List.fromList(utf8.encode(content)));
  }

  void addBytes(String fileName, Uint8List bytes) {
    final normalized = _safeArchivePath(fileName);
    if (_entries.any((entry) => entry.fileName == normalized)) {
      throw StateError('Файл ZIP уже добавлен: $normalized');
    }
    _entries.add(_ZipEntry(fileName: normalized, bytes: bytes));
  }

  Uint8List build() {
    if (_entries.length > 0xffff) {
      throw StateError('Слишком много файлов для ZIP32.');
    }
    final output = BytesBuilder(copy: false);
    final central = BytesBuilder(copy: false);
    var offset = 0;
    for (final entry in _entries) {
      final nameBytes = Uint8List.fromList(utf8.encode(entry.fileName));
      final checksum = _crc32(entry.bytes);
      if (entry.bytes.length > 0xffffffff || offset > 0xffffffff) {
        throw StateError('ZIP32 не поддерживает файл такого размера.');
      }
      final local = BytesBuilder(copy: false)
        ..add(_uint32(0x04034b50))
        ..add(_uint16(20))
        ..add(_uint16(0x0800))
        ..add(_uint16(0))
        ..add(_uint16(0))
        ..add(_uint16(33))
        ..add(_uint32(checksum))
        ..add(_uint32(entry.bytes.length))
        ..add(_uint32(entry.bytes.length))
        ..add(_uint16(nameBytes.length))
        ..add(_uint16(0))
        ..add(nameBytes)
        ..add(entry.bytes);
      final localBytes = local.takeBytes();
      output.add(localBytes);

      central
        ..add(_uint32(0x02014b50))
        ..add(_uint16(20))
        ..add(_uint16(20))
        ..add(_uint16(0x0800))
        ..add(_uint16(0))
        ..add(_uint16(0))
        ..add(_uint16(33))
        ..add(_uint32(checksum))
        ..add(_uint32(entry.bytes.length))
        ..add(_uint32(entry.bytes.length))
        ..add(_uint16(nameBytes.length))
        ..add(_uint16(0))
        ..add(_uint16(0))
        ..add(_uint16(0))
        ..add(_uint16(0))
        ..add(_uint32(0))
        ..add(_uint32(offset))
        ..add(nameBytes);
      offset += localBytes.length;
    }

    final centralBytes = central.takeBytes();
    output
      ..add(centralBytes)
      ..add(_uint32(0x06054b50))
      ..add(_uint16(0))
      ..add(_uint16(0))
      ..add(_uint16(_entries.length))
      ..add(_uint16(_entries.length))
      ..add(_uint32(centralBytes.length))
      ..add(_uint32(offset))
      ..add(_uint16(0));
    return output.takeBytes();
  }

  static Map<String, Uint8List> readStoredEntries(Uint8List archive) {
    final entries = <String, Uint8List>{};
    var offset = 0;
    while (offset + 4 <= archive.length) {
      final signature = _readUint32(archive, offset);
      if (signature == 0x02014b50 || signature == 0x06054b50) {
        break;
      }
      if (signature != 0x04034b50 || offset + 30 > archive.length) {
        throw const FormatException('Некорректный локальный заголовок ZIP.');
      }
      final compression = _readUint16(archive, offset + 8);
      if (compression != 0) {
        throw const FormatException('Ожидался ZIP без сжатия.');
      }
      final size = _readUint32(archive, offset + 18);
      final nameLength = _readUint16(archive, offset + 26);
      final extraLength = _readUint16(archive, offset + 28);
      final nameStart = offset + 30;
      final dataStart = nameStart + nameLength + extraLength;
      final dataEnd = dataStart + size;
      if (dataEnd > archive.length) {
        throw const FormatException('ZIP обрывается внутри файла.');
      }
      final name = utf8.decode(
        archive.sublist(nameStart, nameStart + nameLength),
      );
      entries[name] = Uint8List.fromList(archive.sublist(dataStart, dataEnd));
      offset = dataEnd;
    }
    return entries;
  }

  static String _safeArchivePath(String value) {
    final normalized = value
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+'), '');
    final segments = normalized.split('/');
    if (normalized.isEmpty ||
        segments.any((segment) => segment.isEmpty || segment == '..')) {
      throw FormatException('Недопустимый путь внутри ZIP: $value');
    }
    return normalized;
  }

  static Uint8List _uint16(int value) {
    final bytes = ByteData(2)..setUint16(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }

  static Uint8List _uint32(int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }

  static int _readUint16(Uint8List bytes, int offset) {
    return ByteData.sublistView(
      bytes,
      offset,
      offset + 2,
    ).getUint16(0, Endian.little);
  }

  static int _readUint32(Uint8List bytes, int offset) {
    return ByteData.sublistView(
      bytes,
      offset,
      offset + 4,
    ).getUint32(0, Endian.little);
  }

  static int _crc32(Uint8List bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc = _crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  static final List<int> _crcTable = List<int>.generate(256, (index) {
    var value = index;
    for (var bit = 0; bit < 8; bit += 1) {
      value = (value & 1) == 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
    }
    return value;
  }, growable: false);
}

class _AttachmentReference {
  const _AttachmentReference({required this.rawTarget, required this.sourcePath});

  final String rawTarget;
  final String sourcePath;
}

class _LoadedAsset {
  const _LoadedAsset({
    required this.sourcePath,
    required this.bytes,
    required this.mimeType,
  });

  final String sourcePath;
  final Uint8List bytes;
  final String mimeType;

  String get dataUri => 'data:$mimeType;base64,${base64Encode(bytes)}';
}

class _LoadedAssets {
  const _LoadedAssets({required this.assets, required this.missing});

  final List<_LoadedAsset> assets;
  final List<String> missing;

  Map<String, _LoadedAsset> get bySourcePath => <String, _LoadedAsset>{
    for (final asset in assets) asset.sourcePath: asset,
  };
}

class _ZipEntry {
  const _ZipEntry({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}
