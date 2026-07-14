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

class Project {
  Project({
    required this.id,
    required this.title,
    required this.emoji,
    this.description = '',
    this.colorValue = 0xFF6750A4,
    this.dueAt,
    this.budgetMinutes,
    this.archived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String emoji;
  String description;
  int colorValue;
  DateTime? dueAt;
  int? budgetMinutes;
  bool archived;
  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'description': description,
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
    'description': description,
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
    colorValue: _readInt(json['colorValue'], fallback: 0xFF6750A4),
    dueAt: _readNullableDate(json['dueAt']),
    budgetMinutes:
        json['budgetMinutes'] == null ? null : _readInt(json['budgetMinutes']),
    archived: _readBool(json['archived']),
    createdAt: _readDate(json['createdAt']),
    updatedAt: _readDate(json['updatedAt']),
  );

  factory Project.fromDb(Map<String, Object?> row) => Project(
    id: row['id']! as String,
    title: row['title']! as String,
    emoji: row['emoji'] as String? ?? '📁',
    description: row['description'] as String? ?? '',
    colorValue: _readInt(row['color_value'], fallback: 0xFF6750A4),
    dueAt: _readNullableDate(row['due_at']),
    budgetMinutes:
        row['budget_minutes'] == null ? null : _readInt(row['budget_minutes']),
    archived: _readBool(row['archived']),
    createdAt: _readDate(row['created_at']),
    updatedAt: _readDate(row['updated_at']),
  );
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
    createdAt: _readDate(json['createdAt']),
    updatedAt: _readDate(json['updatedAt']),
    deletedAt: _readNullableDate(json['deletedAt']),
  );

  factory Note.fromDb(Map<String, Object?> row) {
    final rawTags = row['tags_json'] as String? ?? '[]';
    final parsedTags = jsonDecode(rawTags) as List<dynamic>;
    return Note(
      id: row['id']! as String,
      title: row['title']! as String,
      projectId: row['project_id']! as String,
      body: row['body'] as String? ?? '',
      tags: parsedTags.map((tag) => tag.toString()).toList(),
      status: row['status'] as String? ?? 'draft',
      createdAt: _readDate(row['created_at']),
      updatedAt: _readDate(row['updated_at']),
      deletedAt: _readNullableDate(row['deleted_at']),
    );
  }
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
  AppData({
    required this.projects,
    required this.tasks,
    required this.notes,
    required this.entries,
  });

  factory AppData.empty() =>
      AppData(projects: [], tasks: [], notes: [], entries: []);

  List<Project> projects;
  List<WorkTask> tasks;
  List<Note> notes;
  List<TimeEntry> entries;

  String encode() => jsonEncode({
    'format': 'chronicle-backup',
    'version': 2,
    'exportedAt': DateTime.now().toIso8601String(),
    'projects': projects.map((item) => item.toJson()).toList(),
    'tasks': tasks.map((item) => item.toJson()).toList(),
    'notes': notes.map((item) => item.toJson()).toList(),
    'entries': entries.map((item) => item.toJson()).toList(),
  });

  factory AppData.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
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
    );
  }
}
