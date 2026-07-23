import 'dart:convert';

DateTime _readDate(dynamic value, {DateTime? fallback}) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback ?? DateTime.now();
}

DateTime? _readNullableDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  return false;
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

const String _projectResearchPrefix = 'chronicle-project-research-v1:';

List<String> _readStringList(dynamic value) {
  if (value is! List) return <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

class _ProjectDescriptionPayload {
  const _ProjectDescriptionPayload({
    required this.description,
    required this.researchGoal,
    required this.researchQuestions,
    required this.knownFindings,
    required this.openChecks,
    required this.pinnedNoteIds,
    required this.linkedSourceIds,
  });

  final String description;
  final String researchGoal;
  final List<String> researchQuestions;
  final List<String> knownFindings;
  final List<String> openChecks;
  final List<String> pinnedNoteIds;
  final List<String> linkedSourceIds;
}

_ProjectDescriptionPayload _decodeProjectDescription(String raw) {
  if (!raw.startsWith(_projectResearchPrefix)) {
    return _ProjectDescriptionPayload(
      description: raw,
      researchGoal: '',
      researchQuestions: const <String>[],
      knownFindings: const <String>[],
      openChecks: const <String>[],
      pinnedNoteIds: const <String>[],
      linkedSourceIds: const <String>[],
    );
  }
  try {
    final decoded = jsonDecode(raw.substring(_projectResearchPrefix.length));
    if (decoded is! Map) throw const FormatException('Invalid project data');
    final json = Map<String, dynamic>.from(decoded);
    return _ProjectDescriptionPayload(
      description: json['description'] as String? ?? '',
      researchGoal: json['researchGoal'] as String? ?? '',
      researchQuestions: _readStringList(json['researchQuestions']),
      knownFindings: _readStringList(json['knownFindings']),
      openChecks: _readStringList(json['openChecks']),
      pinnedNoteIds: _readStringList(json['pinnedNoteIds']),
      linkedSourceIds: _readStringList(json['linkedSourceIds']),
    );
  } on Object {
    return _ProjectDescriptionPayload(
      description: raw,
      researchGoal: '',
      researchQuestions: const <String>[],
      knownFindings: const <String>[],
      openChecks: const <String>[],
      pinnedNoteIds: const <String>[],
      linkedSourceIds: const <String>[],
    );
  }
}

String _encodeProjectDescription(Project project) {
  final hasResearchData =
      project.researchGoal.trim().isNotEmpty ||
      project.researchQuestions.isNotEmpty ||
      project.knownFindings.isNotEmpty ||
      project.openChecks.isNotEmpty ||
      project.pinnedNoteIds.isNotEmpty ||
      project.linkedSourceIds.isNotEmpty;
  if (!hasResearchData) return project.description;
  final payload = jsonEncode(<String, Object?>{
    'description': project.description,
    'researchGoal': project.researchGoal,
    'researchQuestions': project.researchQuestions,
    'knownFindings': project.knownFindings,
    'openChecks': project.openChecks,
    'pinnedNoteIds': project.pinnedNoteIds,
    'linkedSourceIds': project.linkedSourceIds,
  });
  return '$_projectResearchPrefix$payload';
}

class Project {
  Project({
    required this.id,
    required this.title,
    required this.emoji,
    this.description = '',
    this.researchGoal = '',
    List<String> researchQuestions = const <String>[],
    List<String> knownFindings = const <String>[],
    List<String> openChecks = const <String>[],
    List<String> pinnedNoteIds = const <String>[],
    List<String> linkedSourceIds = const <String>[],
    this.colorValue = 0xFF6750A4,
    this.dueAt,
    this.budgetMinutes,
    this.archived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : researchQuestions = List<String>.from(researchQuestions),
       knownFindings = List<String>.from(knownFindings),
       openChecks = List<String>.from(openChecks),
       pinnedNoteIds = List<String>.from(pinnedNoteIds),
       linkedSourceIds = List<String>.from(linkedSourceIds),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String emoji;
  String description;
  String researchGoal;
  List<String> researchQuestions;
  List<String> knownFindings;
  List<String> openChecks;
  List<String> pinnedNoteIds;
  List<String> linkedSourceIds;
  int colorValue;
  DateTime? dueAt;
  int? budgetMinutes;
  bool archived;
  DateTime createdAt;
  DateTime updatedAt;

  bool get hasResearchProfile =>
      researchGoal.trim().isNotEmpty ||
      researchQuestions.isNotEmpty ||
      knownFindings.isNotEmpty ||
      openChecks.isNotEmpty ||
      pinnedNoteIds.isNotEmpty ||
      linkedSourceIds.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'description': description,
    'researchGoal': researchGoal,
    'researchQuestions': researchQuestions,
    'knownFindings': knownFindings,
    'openChecks': openChecks,
    'pinnedNoteIds': pinnedNoteIds,
    'linkedSourceIds': linkedSourceIds,
    'colorValue': colorValue,
    'dueAt': dueAt?.toIso8601String(),
    'budgetMinutes': budgetMinutes,
    'archived': archived,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Map<String, Object?> toDb() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'description': _encodeProjectDescription(this),
    'color_value': colorValue,
    'due_at': dueAt?.toIso8601String(),
    'budget_minutes': budgetMinutes,
    'archived': archived ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    title: json['title'] as String,
    emoji: json['emoji'] as String? ?? '📁',
    description: json['description'] as String? ?? '',
    researchGoal: json['researchGoal'] as String? ?? '',
    researchQuestions: _readStringList(json['researchQuestions']),
    knownFindings: _readStringList(json['knownFindings']),
    openChecks: _readStringList(json['openChecks']),
    pinnedNoteIds: _readStringList(json['pinnedNoteIds']),
    linkedSourceIds: _readStringList(json['linkedSourceIds']),
    colorValue: _readInt(json['colorValue'], fallback: 0xFF6750A4),
    dueAt: _readNullableDate(json['dueAt']),
    budgetMinutes:
        json['budgetMinutes'] == null ? null : _readInt(json['budgetMinutes']),
    archived: _readBool(json['archived']),
    createdAt: _readDate(json['createdAt']),
    updatedAt: _readDate(json['updatedAt']),
  );

  factory Project.fromDb(Map<String, Object?> row) {
    final payload = _decodeProjectDescription(
      row['description'] as String? ?? '',
    );
    return Project(
      id: row['id']! as String,
      title: row['title']! as String,
      emoji: row['emoji'] as String? ?? '📁',
      description: payload.description,
      researchGoal: payload.researchGoal,
      researchQuestions: payload.researchQuestions,
      knownFindings: payload.knownFindings,
      openChecks: payload.openChecks,
      pinnedNoteIds: payload.pinnedNoteIds,
      linkedSourceIds: payload.linkedSourceIds,
      colorValue: _readInt(row['color_value'], fallback: 0xFF6750A4),
      dueAt: _readNullableDate(row['due_at']),
      budgetMinutes:
          row['budget_minutes'] == null
              ? null
              : _readInt(row['budget_minutes']),
      archived: _readBool(row['archived']),
      createdAt: _readDate(row['created_at']),
      updatedAt: _readDate(row['updated_at']),
    );
  }
}

class WorkTask {
  WorkTask({
    required this.id,
    required this.title,
    required this.projectId,
    this.description = '',
    this.parentTaskId,
    this.noteId,
    this.status = 'next',
    this.priority = 1,
    this.estimateMinutes = 30,
    this.sortOrder = 0,
    this.dueAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String projectId;
  String description;
  String? parentTaskId;
  String? noteId;
  String status;
  int priority;
  int estimateMinutes;
  int sortOrder;
  DateTime? dueAt;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? completedAt;
  DateTime? deletedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'projectId': projectId,
    'description': description,
    'parentTaskId': parentTaskId,
    'noteId': noteId,
    'status': status,
    'priority': priority,
    'estimateMinutes': estimateMinutes,
    'sortOrder': sortOrder,
    'dueAt': dueAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  Map<String, Object?> toDb() => {
    'id': id,
    'title': title,
    'project_id': projectId,
    'description': description,
    'parent_task_id': parentTaskId,
    'note_id': noteId,
    'status': status,
    'priority': priority,
    'estimate_minutes': estimateMinutes,
    'sort_order': sortOrder,
    'due_at': dueAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory WorkTask.fromJson(Map<String, dynamic> json) => WorkTask(
    id: json['id'] as String,
    title: json['title'] as String,
    projectId: json['projectId'] as String,
    description: json['description'] as String? ?? '',
    parentTaskId: json['parentTaskId'] as String?,
    noteId: json['noteId'] as String?,
    status: json['status'] as String? ?? 'next',
    priority: _readInt(json['priority'], fallback: 1),
    estimateMinutes: _readInt(json['estimateMinutes'], fallback: 30),
    sortOrder: _readInt(json['sortOrder']),
    dueAt: _readNullableDate(json['dueAt']),
    createdAt: _readDate(json['createdAt']),
    updatedAt: _readDate(json['updatedAt']),
    completedAt: _readNullableDate(json['completedAt']),
    deletedAt: _readNullableDate(json['deletedAt']),
  );

  factory WorkTask.fromDb(Map<String, Object?> row) => WorkTask(
    id: row['id']! as String,
    title: row['title']! as String,
    projectId: row['project_id']! as String,
    description: row['description'] as String? ?? '',
    parentTaskId: row['parent_task_id'] as String?,
    noteId: row['note_id'] as String?,
    status: row['status'] as String? ?? 'next',
    priority: _readInt(row['priority'], fallback: 1),
    estimateMinutes: _readInt(row['estimate_minutes'], fallback: 30),
    sortOrder: _readInt(row['sort_order']),
    dueAt: _readNullableDate(row['due_at']),
    createdAt: _readDate(row['created_at']),
    updatedAt: _readDate(row['updated_at']),
    completedAt: _readNullableDate(row['completed_at']),
    deletedAt: _readNullableDate(row['deleted_at']),
  );
}

class Note {
  Note({
    required this.id,
    required this.title,
    required this.projectId,
    required this.body,
    this.tags = const [],
    this.status = 'draft',
    this.folderPath = '',
    this.noteType = 'note',
    this.properties = const {},
    this.pinned = false,
    this.revision = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String projectId;
  String body;
  List<String> tags;
  String status;
  String folderPath;
  String noteType;
  Map<String, String> properties;
  bool pinned;
  int revision;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'projectId': projectId,
    'body': body,
    'tags': tags,
    'status': status,
    'folderPath': folderPath,
    'noteType': noteType,
    'properties': properties,
    'pinned': pinned,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  Map<String, Object?> toDb() => {
    'id': id,
    'title': title,
    'project_id': projectId,
    'body': body,
    'tags_json': jsonEncode(tags),
    'status': status,
    'folder_path': folderPath,
    'note_type': noteType,
    'properties_json': jsonEncode(properties),
    'pinned': pinned ? 1 : 0,
    'revision': revision,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    title: json['title'] as String,
    projectId: json['projectId'] as String,
    body: json['body'] as String? ?? '',
    tags: List<String>.from(json['tags'] as List? ?? const []),
    status: json['status'] as String? ?? 'draft',
    folderPath: json['folderPath'] as String? ?? '',
    noteType: json['noteType'] as String? ?? 'note',
    properties: Map<String, String>.from(
      json['properties'] as Map? ?? const <String, String>{},
    ),
    pinned: _readBool(json['pinned']),
    revision: _readInt(json['revision'], fallback: 1),
    createdAt: _readDate(json['createdAt']),
    updatedAt: _readDate(json['updatedAt']),
    deletedAt: _readNullableDate(json['deletedAt']),
  );

  factory Note.fromDb(Map<String, Object?> row) {
    final rawTags = row['tags_json'] as String? ?? '[]';
    final parsedTags = jsonDecode(rawTags) as List<dynamic>;
    final rawProperties = row['properties_json'] as String? ?? '{}';
    final parsedProperties = jsonDecode(rawProperties) as Map<String, dynamic>;
    return Note(
      id: row['id']! as String,
      title: row['title']! as String,
      projectId: row['project_id']! as String,
      body: row['body'] as String? ?? '',
      tags: parsedTags.map((tag) => tag.toString()).toList(),
      status: row['status'] as String? ?? 'draft',
      folderPath: row['folder_path'] as String? ?? '',
      noteType: row['note_type'] as String? ?? 'note',
      properties: parsedProperties.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      pinned: _readBool(row['pinned']),
      revision: _readInt(row['revision'], fallback: 1),
      createdAt: _readDate(row['created_at']),
      updatedAt: _readDate(row['updated_at']),
      deletedAt: _readNullableDate(row['deleted_at']),
    );
  }
}

class NoteLink {
  NoteLink({
    required this.id,
    required this.sourceNoteId,
    required this.targetTitle,
    this.targetNoteId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String sourceNoteId;
  final String targetTitle;
  final String? targetNoteId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceNoteId': sourceNoteId,
    'targetTitle': targetTitle,
    'targetNoteId': targetNoteId,
    'createdAt': createdAt.toIso8601String(),
  };

  Map<String, Object?> toDb() => {
    'id': id,
    'source_note_id': sourceNoteId,
    'target_title': targetTitle,
    'target_note_id': targetNoteId,
    'created_at': createdAt.toIso8601String(),
  };

  factory NoteLink.fromJson(Map<String, dynamic> json) => NoteLink(
    id: json['id'] as String,
    sourceNoteId: json['sourceNoteId'] as String,
    targetTitle: json['targetTitle'] as String,
    targetNoteId: json['targetNoteId'] as String?,
    createdAt: _readDate(json['createdAt']),
  );

  factory NoteLink.fromDb(Map<String, Object?> row) => NoteLink(
    id: row['id']! as String,
    sourceNoteId: row['source_note_id']! as String,
    targetTitle: row['target_title']! as String,
    targetNoteId: row['target_note_id'] as String?,
    createdAt: _readDate(row['created_at']),
  );
}

class NoteVersion {
  NoteVersion({
    required this.id,
    required this.noteId,
    required this.title,
    required this.body,
    this.tags = const [],
    this.status = 'draft',
    this.folderPath = '',
    this.noteType = 'note',
    this.properties = const {},
    this.reason = 'manual',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String noteId;
  final String title;
  final String body;
  final List<String> tags;
  final String status;
  final String folderPath;
  final String noteType;
  final Map<String, String> properties;
  final String reason;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'noteId': noteId,
    'title': title,
    'body': body,
    'tags': tags,
    'status': status,
    'folderPath': folderPath,
    'noteType': noteType,
    'properties': properties,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
  };

  Map<String, Object?> toDb() => {
    'id': id,
    'note_id': noteId,
    'title': title,
    'body': body,
    'tags_json': jsonEncode(tags),
    'status': status,
    'folder_path': folderPath,
    'note_type': noteType,
    'properties_json': jsonEncode(properties),
    'reason': reason,
    'created_at': createdAt.toIso8601String(),
  };

  factory NoteVersion.fromJson(Map<String, dynamic> json) => NoteVersion(
    id: json['id'] as String,
    noteId: json['noteId'] as String,
    title: json['title'] as String,
    body: json['body'] as String? ?? '',
    tags: List<String>.from(json['tags'] as List? ?? const []),
    status: json['status'] as String? ?? 'draft',
    folderPath: json['folderPath'] as String? ?? '',
    noteType: json['noteType'] as String? ?? 'note',
    properties: Map<String, String>.from(
      json['properties'] as Map? ?? const <String, String>{},
    ),
    reason: json['reason'] as String? ?? 'manual',
    createdAt: _readDate(json['createdAt']),
  );

  factory NoteVersion.fromDb(Map<String, Object?> row) {
    final parsedTags = jsonDecode(row['tags_json'] as String? ?? '[]') as List;
    final parsedProperties =
        jsonDecode(row['properties_json'] as String? ?? '{}')
            as Map<String, dynamic>;
    return NoteVersion(
      id: row['id']! as String,
      noteId: row['note_id']! as String,
      title: row['title']! as String,
      body: row['body'] as String? ?? '',
      tags: parsedTags.map((tag) => tag.toString()).toList(),
      status: row['status'] as String? ?? 'draft',
      folderPath: row['folder_path'] as String? ?? '',
      noteType: row['note_type'] as String? ?? 'note',
      properties: parsedProperties.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      reason: row['reason'] as String? ?? 'manual',
      createdAt: _readDate(row['created_at']),
    );
  }
}


class CitationSource {
  CitationSource({
    required this.id,
    required this.citationKey,
    required this.title,
    this.sourceType = 'article',
    List<String> authors = const [],
    this.year,
    this.containerTitle = '',
    this.doi = '',
    this.pmid = '',
    this.arxivId = '',
    this.url = '',
    this.pdfPath = '',
    List<String> tags = const [],
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : authors = List<String>.from(authors),
       tags = List<String>.from(tags),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String citationKey;
  String title;
  String sourceType;
  List<String> authors;
  int? year;
  String containerTitle;
  String doi;
  String pmid;
  String arxivId;
  String url;
  String pdfPath;
  List<String> tags;
  String note;
  DateTime createdAt;
  DateTime updatedAt;

  String get normalizedCitationKey => citationKey.trim().toLowerCase();

  String get normalizedDoi {
    var value = doi.trim().toLowerCase();
    value = value.replaceFirst(RegExp(r'^https?://(?:dx\.)?doi\.org/'), '');
    return value.replaceFirst(RegExp(r'^doi:\s*'), '');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'citationKey': citationKey,
    'title': title,
    'sourceType': sourceType,
    'authors': authors,
    'year': year,
    'containerTitle': containerTitle,
    'doi': doi,
    'pmid': pmid,
    'arxivId': arxivId,
    'url': url,
    'pdfPath': pdfPath,
    'tags': tags,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CitationSource.fromJson(Map<String, dynamic> json) => CitationSource(
    id: json['id'] as String,
    citationKey: json['citationKey'] as String? ?? '',
    title: json['title'] as String? ?? '',
    sourceType: json['sourceType'] as String? ?? 'article',
    authors: List<String>.from(json['authors'] as List? ?? const []),
    year: json['year'] == null ? null : _readInt(json['year']),
    containerTitle: json['containerTitle'] as String? ?? '',
    doi: json['doi'] as String? ?? '',
    pmid: json['pmid'] as String? ?? '',
    arxivId: json['arxivId'] as String? ?? '',
    url: json['url'] as String? ?? '',
    pdfPath: json['pdfPath'] as String? ?? '',
    tags: List<String>.from(json['tags'] as List? ?? const []),
    note: json['note'] as String? ?? '',
    createdAt: _readDate(json['createdAt']),
    updatedAt: _readDate(json['updatedAt']),
  );
}

class TimeEntry {
  TimeEntry({
    required this.id,
    required this.description,
    required this.projectId,
    this.taskId,
    this.noteId,
    required this.startedAt,
    required this.durationSeconds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String description;
  String projectId;
  String? taskId;
  String? noteId;
  DateTime startedAt;
  int durationSeconds;
  DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'projectId': projectId,
    'taskId': taskId,
    'noteId': noteId,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'createdAt': createdAt.toIso8601String(),
  };

  Map<String, Object?> toDb() => {
    'id': id,
    'description': description,
    'project_id': projectId,
    'task_id': taskId,
    'note_id': noteId,
    'started_at': startedAt.toIso8601String(),
    'duration_seconds': durationSeconds,
    'created_at': createdAt.toIso8601String(),
  };

  factory TimeEntry.fromJson(Map<String, dynamic> json) => TimeEntry(
    id: json['id'] as String,
    description: json['description'] as String? ?? '',
    projectId: json['projectId'] as String,
    taskId: json['taskId'] as String?,
    noteId: json['noteId'] as String?,
    startedAt: _readDate(json['startedAt']),
    durationSeconds: _readInt(json['durationSeconds']),
    createdAt: _readDate(json['createdAt']),
  );

  factory TimeEntry.fromDb(Map<String, Object?> row) => TimeEntry(
    id: row['id']! as String,
    description: row['description'] as String? ?? '',
    projectId: row['project_id']! as String,
    taskId: row['task_id'] as String?,
    noteId: row['note_id'] as String?,
    startedAt: _readDate(row['started_at']),
    durationSeconds: _readInt(row['duration_seconds']),
    createdAt: _readDate(row['created_at']),
  );
}

class ActiveTimerState {
  ActiveTimerState({
    required this.startedAt,
    required this.description,
    required this.projectId,
    this.taskId,
    this.noteId,
  });

  final DateTime startedAt;
  final String description;
  final String projectId;
  final String? taskId;
  final String? noteId;

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'description': description,
    'projectId': projectId,
    'taskId': taskId,
    'noteId': noteId,
  };

  factory ActiveTimerState.fromJson(Map<String, dynamic> json) =>
      ActiveTimerState(
        startedAt: _readDate(json['startedAt']),
        description: json['description'] as String? ?? '',
        projectId: json['projectId'] as String,
        taskId: json['taskId'] as String?,
        noteId: json['noteId'] as String?,
      );
}

class AppData {
  static const String backupFormat = 'chronicle-backup';
  static const int currentBackupFormatVersion = 5;
  static const int minimumReadableBackupFormatVersion = 1;

  AppData({
    required this.projects,
    required this.tasks,
    required this.notes,
    required this.entries,
    List<NoteLink>? noteLinks,
    List<NoteVersion>? noteVersions,
    List<CitationSource>? citationSources,
  }) : noteLinks = noteLinks ?? [],
       noteVersions = noteVersions ?? [],
       citationSources = citationSources ?? [];

  factory AppData.empty() =>
      AppData(projects: [], tasks: [], notes: [], entries: []);

  List<Project> projects;
  List<WorkTask> tasks;
  List<Note> notes;
  List<TimeEntry> entries;
  List<NoteLink> noteLinks;
  List<NoteVersion> noteVersions;
  List<CitationSource> citationSources;

  String encode() => jsonEncode({
    'format': backupFormat,
    'version': currentBackupFormatVersion,
    'minimumReaderVersion': minimumReadableBackupFormatVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'projects': projects.map((item) => item.toJson()).toList(),
    'tasks': tasks.map((item) => item.toJson()).toList(),
    'notes': notes.map((item) => item.toJson()).toList(),
    'entries': entries.map((item) => item.toJson()).toList(),
    'noteLinks': noteLinks.map((item) => item.toJson()).toList(),
    'noteVersions': noteVersions.map((item) => item.toJson()).toList(),
    'citationSources': citationSources.map((item) => item.toJson()).toList(),
  });

  static int formatVersionOf(String raw) {
    final json = _decodeBackupEnvelope(raw);
    return _formatVersionOfJson(json);
  }

  static Map<String, dynamic> _decodeBackupEnvelope(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Некорректный формат резервной копии.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static int _formatVersionOfJson(Map<String, dynamic> json) {
    final format = json['format']?.toString();
    if (format != null && format.isNotEmpty && format != backupFormat) {
      throw FormatException('Неизвестный формат резервной копии: $format.');
    }
    final rawVersion = json['version'];
    final version = rawVersion == null
        ? minimumReadableBackupFormatVersion
        : _readInt(rawVersion, fallback: 0);
    if (version < minimumReadableBackupFormatVersion) {
      throw FormatException('Некорректная версия резервной копии: $version.');
    }
    final minimumReaderVersion = _readInt(
      json['minimumReaderVersion'],
      fallback: minimumReadableBackupFormatVersion,
    );
    if (minimumReaderVersion < minimumReadableBackupFormatVersion) {
      throw FormatException(
        'Некорректная минимальная версия чтения: $minimumReaderVersion.',
      );
    }
    if (version > currentBackupFormatVersion ||
        minimumReaderVersion > currentBackupFormatVersion) {
      throw UnsupportedError(
        'Эта копия создана более новой версией Chronicle '
        '(формат $version, требуется reader $minimumReaderVersion, '
        'поддерживается до $currentBackupFormatVersion).',
      );
    }
    return version;
  }

  factory AppData.decode(String raw) {
    final json = _decodeBackupEnvelope(raw);
    _formatVersionOfJson(json);
    return AppData(
      projects:
          (json['projects'] as List<dynamic>? ?? const [])
              .map((item) => Project.fromJson(item as Map<String, dynamic>))
              .toList(),
      tasks:
          (json['tasks'] as List<dynamic>? ?? const [])
              .map((item) => WorkTask.fromJson(item as Map<String, dynamic>))
              .toList(),
      notes:
          (json['notes'] as List<dynamic>? ?? const [])
              .map((item) => Note.fromJson(item as Map<String, dynamic>))
              .toList(),
      entries:
          (json['entries'] as List<dynamic>? ?? const [])
              .map((item) => TimeEntry.fromJson(item as Map<String, dynamic>))
              .toList(),
      noteLinks:
          (json['noteLinks'] as List<dynamic>? ?? const [])
              .map((item) => NoteLink.fromJson(item as Map<String, dynamic>))
              .toList(),
      noteVersions:
          (json['noteVersions'] as List<dynamic>? ?? const [])
              .map((item) => NoteVersion.fromJson(item as Map<String, dynamic>))
              .toList(),
      citationSources:
          (json['citationSources'] as List<dynamic>? ?? const [])
              .map(
                (item) => CitationSource.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}
