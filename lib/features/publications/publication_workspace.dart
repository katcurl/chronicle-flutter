import 'dart:convert';

import '../../models/app_models.dart';
import '../notes/note_document.dart';
import '../notes/note_image_syntax.dart';
import '../references/citation_syntax.dart';

enum PublicationKind { article, report, presentation }

extension PublicationKindDetails on PublicationKind {
  String get label => switch (this) {
    PublicationKind.article => 'Статья',
    PublicationKind.report => 'Отчёт',
    PublicationKind.presentation => 'Презентационный конспект',
  };

  String get emoji => switch (this) {
    PublicationKind.article => '📝',
    PublicationKind.report => '📊',
    PublicationKind.presentation => '🎞️',
  };

  String get description => switch (this) {
    PublicationKind.article =>
      'Связный научный текст с введением, методами, результатами и обсуждением.',
    PublicationKind.report =>
      'Практический или исследовательский отчёт с задачами, ходом работы и выводами.',
    PublicationKind.presentation =>
      'Короткая логика доклада: проблема, ключевые результаты и финальный вывод.',
  };
}

class PublicationFragment {
  PublicationFragment({
    required this.id,
    required this.noteId,
    this.heading = '',
  });

  final String id;
  final String noteId;
  final String heading;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'noteId': noteId,
    'heading': heading,
  };

  factory PublicationFragment.fromJson(Map<String, Object?> json) {
    return PublicationFragment(
      id: json['id']?.toString() ?? '',
      noteId: json['noteId']?.toString() ?? '',
      heading: json['heading']?.toString() ?? '',
    );
  }
}

class PublicationSection {
  PublicationSection({
    required this.id,
    required this.title,
    this.text = '',
    List<PublicationFragment> fragments = const <PublicationFragment>[],
  }) : fragments = List<PublicationFragment>.from(fragments);

  final String id;
  String title;
  String text;
  final List<PublicationFragment> fragments;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'text': text,
    'fragments': <Map<String, Object?>>[
      for (final fragment in fragments) fragment.toJson(),
    ],
  };

  factory PublicationSection.fromJson(Map<String, Object?> json) {
    final rawFragments = json['fragments'];
    return PublicationSection(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      fragments: rawFragments is List
          ? <PublicationFragment>[
              for (final item in rawFragments)
                if (item is Map)
                  PublicationFragment.fromJson(
                    item.map(
                      (key, value) => MapEntry(key.toString(), value),
                    ),
                  ),
            ]
          : const <PublicationFragment>[],
    );
  }
}

class PublicationWorkspace {
  PublicationWorkspace({
    required this.kind,
    required List<PublicationSection> sections,
    this.numberFigures = true,
    this.numberTables = true,
    this.includeAbbreviations = true,
    this.includeBibliography = true,
  }) : sections = List<PublicationSection>.from(sections);

  PublicationKind kind;
  final List<PublicationSection> sections;
  bool numberFigures;
  bool numberTables;
  bool includeAbbreviations;
  bool includeBibliography;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 1,
    'kind': kind.name,
    'numberFigures': numberFigures,
    'numberTables': numberTables,
    'includeAbbreviations': includeAbbreviations,
    'includeBibliography': includeBibliography,
    'sections': <Map<String, Object?>>[
      for (final section in sections) section.toJson(),
    ],
  };

  factory PublicationWorkspace.fromJson(
    Map<String, Object?> json, {
    required String Function() idFactory,
  }) {
    final rawKind = json['kind']?.toString();
    final kind = PublicationKind.values.firstWhere(
      (candidate) => candidate.name == rawKind,
      orElse: () => PublicationKind.report,
    );
    final rawSections = json['sections'];
    final sections = rawSections is List
        ? <PublicationSection>[
            for (final item in rawSections)
              if (item is Map)
                PublicationSection.fromJson(
                  item.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
          ]
        : <PublicationSection>[];
    final normalizedSections = <PublicationSection>[
      for (final section in sections)
        PublicationSection(
          id: section.id.trim().isEmpty ? idFactory() : section.id,
          title: section.title.trim().isEmpty ? 'Раздел' : section.title,
          text: section.text,
          fragments: <PublicationFragment>[
            for (final fragment in section.fragments)
              PublicationFragment(
                id: fragment.id.trim().isEmpty ? idFactory() : fragment.id,
                noteId: fragment.noteId,
                heading: fragment.heading,
              ),
          ],
        ),
    ];
    return PublicationWorkspace(
      kind: kind,
      sections: normalizedSections.isEmpty
          ? PublicationWorkspaceTemplates.create(kind, idFactory: idFactory)
              .sections
          : normalizedSections,
      numberFigures: _readBool(json['numberFigures'], fallback: true),
      numberTables: _readBool(json['numberTables'], fallback: true),
      includeAbbreviations: _readBool(
        json['includeAbbreviations'],
        fallback: kind != PublicationKind.presentation,
      ),
      includeBibliography: _readBool(
        json['includeBibliography'],
        fallback: true,
      ),
    );
  }

  static bool _readBool(Object? value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return fallback;
  }
}

class PublicationWorkspaceTemplates {
  const PublicationWorkspaceTemplates._();

  static PublicationWorkspace create(
    PublicationKind kind, {
    required String Function() idFactory,
  }) {
    final titles = switch (kind) {
      PublicationKind.article => const <String>[
        'Введение',
        'Материалы и методы',
        'Результаты',
        'Обсуждение',
        'Выводы',
      ],
      PublicationKind.report => const <String>[
        'Цель и задачи',
        'Теоретическая основа',
        'Ход работы',
        'Полученные результаты',
        'Выводы',
      ],
      PublicationKind.presentation => const <String>[
        'Проблема',
        'Подход',
        'Ключевые результаты',
        'Интерпретация',
        'Главный вывод',
      ],
    };
    return PublicationWorkspace(
      kind: kind,
      sections: <PublicationSection>[
        for (final title in titles)
          PublicationSection(id: idFactory(), title: title),
      ],
      includeAbbreviations: kind != PublicationKind.presentation,
    );
  }
}

class PublicationHeading {
  const PublicationHeading({required this.level, required this.title});

  final int level;
  final String title;
}

class PublicationAssemblyIssue {
  const PublicationAssemblyIssue({
    required this.fragmentId,
    required this.message,
  });

  final String fragmentId;
  final String message;
}

class PublicationAssembly {
  const PublicationAssembly({
    required this.markdown,
    required this.wordCount,
    required this.figureCount,
    required this.tableCount,
    required this.liveFragmentCount,
    required this.abbreviations,
    required this.issues,
  });

  final String markdown;
  final int wordCount;
  final int figureCount;
  final int tableCount;
  final int liveFragmentCount;
  final Map<String, String> abbreviations;
  final List<PublicationAssemblyIssue> issues;
}

class PublicationWorkspaceCodec {
  const PublicationWorkspaceCodec._();

  static const String workspaceProperty = 'chronicle_publication_workspace';
  static const String kindProperty = 'chronicle_publication_kind';

  static bool isPublication(Note note) {
    return note.noteType == 'publication' ||
        note.properties.containsKey(workspaceProperty);
  }

  static PublicationWorkspace read(
    Note note, {
    required String Function() idFactory,
  }) {
    final raw = note.properties[workspaceProperty];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return PublicationWorkspace.fromJson(
            decoded.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
            idFactory: idFactory,
          );
        }
      } on Object {
        // A damaged publication property falls back to a safe template.
      }
    }
    final rawKind = note.properties[kindProperty];
    final kind = PublicationKind.values.firstWhere(
      (candidate) => candidate.name == rawKind,
      orElse: () => PublicationKind.report,
    );
    return PublicationWorkspaceTemplates.create(kind, idFactory: idFactory);
  }

  static void write(
    Note note,
    PublicationWorkspace workspace,
    Iterable<Note> sourceNotes,
  ) {
    note.noteType = 'publication';
    note.folderPath = note.folderPath.trim().isEmpty
        ? 'Публикации и отчёты'
        : note.folderPath;
    note.properties = <String, String>{
      ...note.properties,
      workspaceProperty: jsonEncode(workspace.toJson()),
      kindProperty: workspace.kind.name,
    };
    note.body = NoteDocument.serialize(
      note,
      manifestMarkdown(workspace, sourceNotes),
    );
  }

  static String manifestMarkdown(
    PublicationWorkspace workspace,
    Iterable<Note> sourceNotes,
  ) {
    final notesById = <String, Note>{
      for (final note in sourceNotes) note.id: note,
    };
    final buffer = StringBuffer()
      ..writeln(
        '> Этот документ собирается из живых фрагментов заметок. '
        'Chronicle не копирует исходный текст и не переписывает его автоматически.',
      )
      ..writeln();
    for (final section in workspace.sections) {
      final sectionTitle = section.title.trim().isEmpty
          ? 'Раздел'
          : section.title.trim();
      buffer
        ..writeln('## $sectionTitle')
        ..writeln();
      if (section.text.trim().isNotEmpty) {
        buffer
          ..writeln(section.text.trim())
          ..writeln();
      }
      for (final fragment in section.fragments) {
        final source = notesById[fragment.noteId];
        final label = source?.title ?? 'Потерянная заметка';
        final safeLabel = label.replaceAll('|', '¦').replaceAll(']', '');
        final detail = fragment.heading.trim().isEmpty
            ? 'вся заметка'
            : 'раздел «${fragment.heading.trim()}»';
        buffer.writeln(
          '- [[id:${fragment.noteId}|$safeLabel]] — живой фрагмент: $detail',
        );
      }
      buffer.writeln();
    }
    return '${buffer.toString().trimRight()}\n';
  }
}

String? publicationFragmentContent(Note note, String heading) {
  return _extractFragment(note, heading);
}

List<PublicationHeading> publicationHeadings(Note note) {
  final content = NoteDocument.parse(note.body).content;
  final headings = <PublicationHeading>[];
  final seen = <String>{};
  final pattern = RegExp(r'^\s{0,3}(#{1,6})\s+(.+?)\s*#*\s*$');
  var fenced = false;
  for (final line in content.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      fenced = !fenced;
      continue;
    }
    if (fenced) continue;
    final match = pattern.firstMatch(line);
    if (match == null) continue;
    final title = match.group(2)!.trim();
    if (title.isEmpty || !seen.add(title.toLowerCase())) continue;
    headings.add(
      PublicationHeading(level: match.group(1)!.length, title: title),
    );
  }
  return headings;
}

PublicationAssembly assemblePublication({
  required String title,
  required PublicationWorkspace workspace,
  required Iterable<Note> notes,
  required Iterable<CitationSource> sources,
}) {
  final notesById = <String, Note>{for (final note in notes) note.id: note};
  final issues = <PublicationAssemblyIssue>[];
  final abbreviationSourceBodies = <String>[];
  final abbreviationSourceNoteIds = <String>{};
  final buffer = StringBuffer()
    ..writeln('# ${title.trim().isEmpty ? 'Без названия' : title.trim()}')
    ..writeln();
  var liveFragmentCount = 0;

  for (final section in workspace.sections) {
    final sectionTitle = section.title.trim().isEmpty
        ? 'Раздел'
        : section.title.trim();
    buffer
      ..writeln('## $sectionTitle')
      ..writeln();
    if (section.text.trim().isNotEmpty) {
      buffer
        ..writeln(section.text.trim())
        ..writeln();
    }
    for (final fragment in section.fragments) {
      liveFragmentCount += 1;
      final source = notesById[fragment.noteId];
      if (source == null) {
        issues.add(
          PublicationAssemblyIssue(
            fragmentId: fragment.id,
            message: 'Не найдена исходная заметка для раздела «$sectionTitle».',
          ),
        );
        continue;
      }
      final extracted = _extractFragment(source, fragment.heading);
      if (extracted == null) {
        issues.add(
          PublicationAssemblyIssue(
            fragmentId: fragment.id,
            message:
                'В заметке «${source.title}» больше нет заголовка '
                '«${fragment.heading}».',
          ),
        );
        continue;
      }
      final normalized = _stripLeadingTitle(extracted, source.title).trim();
      if (normalized.isEmpty) {
        issues.add(
          PublicationAssemblyIssue(
            fragmentId: fragment.id,
            message: 'Живой фрагмент из «${source.title}» сейчас пуст.',
          ),
        );
        continue;
      }
      if (abbreviationSourceNoteIds.add(source.id)) {
        abbreviationSourceBodies.add(NoteDocument.parse(source.body).content);
      }
      buffer
        ..writeln(normalized)
        ..writeln()
        ..writeln(
          '<!-- Chronicle source: ${source.id}'
          '${fragment.heading.trim().isEmpty ? '' : ' # ${fragment.heading.trim()}'} -->',
        )
        ..writeln();
    }
  }

  var markdown = buffer.toString().trimRight();
  final figureResult = _numberFigures(
    markdown,
    enabled: workspace.numberFigures,
  );
  markdown = figureResult.markdown;
  final tableResult = _numberTables(
    markdown,
    enabled: workspace.numberTables,
  );
  markdown = tableResult.markdown;

  final abbreviationCorpus = <String>[
    markdown,
    ...abbreviationSourceBodies,
  ].join('\n\n');
  final abbreviations = _extractAbbreviations(abbreviationCorpus);
  if (workspace.includeAbbreviations && abbreviations.isNotEmpty) {
    final abbreviationBuffer = StringBuffer()
      ..writeln()
      ..writeln()
      ..writeln('## Список сокращений')
      ..writeln();
    for (final entry in abbreviations.entries) {
      abbreviationBuffer.writeln('- **${entry.key}** — ${entry.value}');
    }
    markdown += abbreviationBuffer.toString();
  }

  final bibliography = CitationSyntax.bibliographyFor(markdown, sources);
  if (workspace.includeBibliography && bibliography.isNotEmpty) {
    markdown = '$markdown\n\n${CitationSyntax.bibliographyMarker}';
  }
  markdown = CitationSyntax.renderMarkdownChunk(
    markdown,
    sources,
    bibliography: bibliography,
  );
  markdown = '${markdown.trimRight()}\n';

  return PublicationAssembly(
    markdown: markdown,
    wordCount: NoteDocument.wordCount(markdown),
    figureCount: figureResult.count,
    tableCount: tableResult.count,
    liveFragmentCount: liveFragmentCount,
    abbreviations: abbreviations,
    issues: List<PublicationAssemblyIssue>.unmodifiable(issues),
  );
}

String? _extractFragment(Note note, String heading) {
  final content = NoteDocument.parse(note.body).content.replaceAll('\r\n', '\n');
  final wanted = heading.trim();
  if (wanted.isEmpty) return content;

  final lines = content.split('\n');
  final pattern = RegExp(r'^\s{0,3}(#{1,6})\s+(.+?)\s*#*\s*$');
  var fenced = false;
  int? start;
  int? level;
  for (var index = 0; index < lines.length; index += 1) {
    final trimmed = lines[index].trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      fenced = !fenced;
      continue;
    }
    if (fenced) continue;
    final match = pattern.firstMatch(lines[index]);
    if (match == null) continue;
    final currentLevel = match.group(1)!.length;
    final currentTitle = match.group(2)!.trim();
    if (start == null && currentTitle.toLowerCase() == wanted.toLowerCase()) {
      start = index + 1;
      level = currentLevel;
      continue;
    }
    if (start != null && currentLevel <= level!) {
      return lines.sublist(start, index).join('\n');
    }
  }
  if (start == null) return null;
  return lines.sublist(start).join('\n');
}

String _stripLeadingTitle(String markdown, String noteTitle) {
  final lines = markdown.split('\n');
  var firstContent = 0;
  while (firstContent < lines.length && lines[firstContent].trim().isEmpty) {
    firstContent += 1;
  }
  if (firstContent >= lines.length) return markdown;
  final match = RegExp(r'^\s*#\s+(.+?)\s*#*\s*$').firstMatch(
    lines[firstContent],
  );
  if (match == null ||
      match.group(1)!.trim().toLowerCase() !=
          noteTitle.trim().toLowerCase()) {
    return markdown;
  }
  lines.removeAt(firstContent);
  return lines.join('\n');
}

class _NumberingResult {
  const _NumberingResult({required this.markdown, required this.count});

  final String markdown;
  final int count;
}

_NumberingResult _numberFigures(String markdown, {required bool enabled}) {
  final references = NoteImageSyntax.all(markdown).toList();
  if (!enabled || references.isEmpty) {
    return _NumberingResult(markdown: markdown, count: references.length);
  }
  var result = markdown;
  for (var index = references.length - 1; index >= 0; index -= 1) {
    final reference = references[index];
    final number = index + 1;
    final rawCaption = reference.presentation.caption.trim().isNotEmpty
        ? reference.presentation.caption.trim()
        : reference.alt.trim();
    final caption = rawCaption.isEmpty
        ? 'Рисунок $number'
        : 'Рисунок $number. $rawCaption';
    final replacement = reference.toMarkdown(
      presentation: reference.presentation.copyWith(
        caption: caption,
        figureId: reference.presentation.figureId.trim().isEmpty
            ? 'figure-$number'
            : reference.presentation.figureId,
      ),
    );
    result = result.replaceRange(reference.start, reference.end, replacement);
  }
  return _NumberingResult(markdown: result, count: references.length);
}

_NumberingResult _numberTables(String markdown, {required bool enabled}) {
  final lines = markdown.split('\n');
  final separator = RegExp(
    r'^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$',
  );
  final output = <String>[];
  var count = 0;
  var fenced = false;
  for (var index = 0; index < lines.length; index += 1) {
    final line = lines[index];
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      fenced = !fenced;
      output.add(line);
      continue;
    }
    final isHeader = !fenced &&
        index + 1 < lines.length &&
        line.contains('|') &&
        separator.hasMatch(lines[index + 1]);
    if (isHeader) {
      count += 1;
      if (enabled) {
        if (output.isNotEmpty && output.last.trim().isNotEmpty) {
          output.add('');
        }
        output
          ..add('**Таблица $count.**')
          ..add('');
      }
    }
    output.add(line);
  }
  return _NumberingResult(markdown: output.join('\n'), count: count);
}

Map<String, String> _extractAbbreviations(String markdown) {
  final result = <String, String>{};
  final abbreviationPattern = RegExp(
    r'\(([A-ZА-ЯЁ][A-ZА-ЯЁ0-9-]{1,11})\)',
  );

  for (final match in abbreviationPattern.allMatches(markdown)) {
    final abbreviation = match.group(1)!.trim();
    final newlineIndex = match.start == 0
        ? -1
        : markdown.lastIndexOf('\n', match.start - 1);
    final rawPrefix = markdown.substring(newlineIndex + 1, match.start);
    final expansion = _abbreviationExpansionFromPrefix(
      rawPrefix,
      abbreviation,
    );
    if (expansion == null) continue;
    result.putIfAbsent(abbreviation, () => expansion);
  }

  final ordered = result.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return <String, String>{for (final entry in ordered) entry.key: entry.value};
}

String? _abbreviationExpansionFromPrefix(
  String rawPrefix,
  String abbreviation,
) {
  var prefix = rawPrefix
      .trimRight()
      .replaceFirst(
        RegExp(r'^\s{0,3}(?:#{1,6}\s+|[-*+]\s+|\d+[.)]\s+)'),
        '',
      )
      .replaceAll(RegExp(r'[*_`~]'), '');
  if (prefix.isEmpty) return null;

  final boundaryMatches = RegExp(r'(?:[.!?;:]\s+|[—–]\s+)').allMatches(prefix);
  if (boundaryMatches.isNotEmpty) {
    prefix = prefix.substring(boundaryMatches.last.end).trimLeft();
  }

  final words = <String>[
    for (final rawWord in prefix.split(RegExp(r'\s+')))
      if (_cleanAbbreviationWord(rawWord).isNotEmpty)
        _cleanAbbreviationWord(rawWord),
  ];
  if (words.isEmpty) return null;

  final normalizedAbbreviation = abbreviation
      .replaceAll('-', '')
      .toUpperCase();
  final maximumWords = words.length < 12 ? words.length : 12;
  for (var count = 1; count <= maximumWords; count += 1) {
    final candidate = words.sublist(words.length - count);
    final initials = candidate
        .map(_abbreviationInitial)
        .where((value) => value.isNotEmpty)
        .join()
        .toUpperCase();
    if (initials == normalizedAbbreviation) {
      final expansion = candidate.join(' ');
      if (expansion.length >= 4 && expansion.length <= 90) return expansion;
    }
  }

  final fallbackStart = words.length > 8 ? words.length - 8 : 0;
  final fallback = words.sublist(fallbackStart).join(' ');
  if (fallback.length < 4 || fallback.length > 90) return null;
  return fallback;
}

String _cleanAbbreviationWord(String value) {
  return value
      .replaceFirst(RegExp(r'^[^A-Za-zА-Яа-яЁё0-9]+'), '')
      .replaceFirst(RegExp(r'[^A-Za-zА-Яа-яЁё0-9-]+$'), '');
}

String _abbreviationInitial(String value) {
  final match = RegExp(r'[A-Za-zА-Яа-яЁё0-9]').firstMatch(value);
  return match?.group(0) ?? '';
}
