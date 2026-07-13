import 'dart:convert';

class Project {
  Project({required this.id, required this.title, required this.emoji, this.description = '', this.archived = false});
  final String id;
  String title;
  String emoji;
  String description;
  bool archived;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'emoji': emoji, 'description': description, 'archived': archived};
  factory Project.fromJson(Map<String, dynamic> j) => Project(id: j['id'], title: j['title'], emoji: j['emoji'] ?? '📁', description: j['description'] ?? '', archived: j['archived'] ?? false);
}

class WorkTask {
  WorkTask({required this.id, required this.title, required this.projectId, this.noteId, this.status = 'next', this.estimateMinutes = 30, this.dueAt});
  final String id;
  String title;
  String projectId;
  String? noteId;
  String status;
  int estimateMinutes;
  DateTime? dueAt;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'projectId': projectId, 'noteId': noteId, 'status': status, 'estimateMinutes': estimateMinutes, 'dueAt': dueAt?.toIso8601String()};
  factory WorkTask.fromJson(Map<String, dynamic> j) => WorkTask(id: j['id'], title: j['title'], projectId: j['projectId'], noteId: j['noteId'], status: j['status'] ?? 'next', estimateMinutes: j['estimateMinutes'] ?? 30, dueAt: j['dueAt'] == null ? null : DateTime.parse(j['dueAt']));
}

class Note {
  Note({required this.id, required this.title, required this.projectId, required this.body, this.tags = const [], this.status = 'draft', DateTime? updatedAt}) : updatedAt = updatedAt ?? DateTime.now();
  final String id;
  String title;
  String projectId;
  String body;
  List<String> tags;
  String status;
  DateTime updatedAt;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'projectId': projectId, 'body': body, 'tags': tags, 'status': status, 'updatedAt': updatedAt.toIso8601String()};
  factory Note.fromJson(Map<String, dynamic> j) => Note(id: j['id'], title: j['title'], projectId: j['projectId'], body: j['body'] ?? '', tags: List<String>.from(j['tags'] ?? []), status: j['status'] ?? 'draft', updatedAt: DateTime.tryParse(j['updatedAt'] ?? ''));
}

class TimeEntry {
  TimeEntry({required this.id, required this.description, required this.projectId, this.taskId, this.noteId, required this.startedAt, required this.durationSeconds});
  final String id;
  String description;
  String projectId;
  String? taskId;
  String? noteId;
  DateTime startedAt;
  int durationSeconds;
  Map<String, dynamic> toJson() => {'id': id, 'description': description, 'projectId': projectId, 'taskId': taskId, 'noteId': noteId, 'startedAt': startedAt.toIso8601String(), 'durationSeconds': durationSeconds};
  factory TimeEntry.fromJson(Map<String, dynamic> j) => TimeEntry(id: j['id'], description: j['description'] ?? '', projectId: j['projectId'], taskId: j['taskId'], noteId: j['noteId'], startedAt: DateTime.parse(j['startedAt']), durationSeconds: j['durationSeconds'] ?? 0);
}

class AppData {
  AppData({required this.projects, required this.tasks, required this.notes, required this.entries});
  List<Project> projects;
  List<WorkTask> tasks;
  List<Note> notes;
  List<TimeEntry> entries;
  String encode() => jsonEncode({'projects': projects.map((e) => e.toJson()).toList(), 'tasks': tasks.map((e) => e.toJson()).toList(), 'notes': notes.map((e) => e.toJson()).toList(), 'entries': entries.map((e) => e.toJson()).toList()});
  factory AppData.decode(String raw) { final j = jsonDecode(raw); return AppData(projects: (j['projects'] as List).map((e) => Project.fromJson(e)).toList(), tasks: (j['tasks'] as List).map((e) => WorkTask.fromJson(e)).toList(), notes: (j['notes'] as List).map((e) => Note.fromJson(e)).toList(), entries: (j['entries'] as List).map((e) => TimeEntry.fromJson(e)).toList()); }
}
