import '../../models/app_models.dart';
import 'app_repository.dart';

class InMemoryAppRepository implements AppRepository {
  InMemoryAppRepository({AppData? initialData})
    : _data = initialData ?? AppData.empty();

  AppData _data;
  bool _initialized = false;
  ActiveTimerState? _activeTimer;

  @override
  Future<bool> isInitialized() async => _initialized;

  @override
  Future<void> markInitialized() async {
    _initialized = true;
  }

  @override
  Future<AppData> load() async => AppData.decode(_data.encode());

  @override
  Future<void> replaceAll(AppData data) async {
    _data = AppData.decode(data.encode());
  }

  @override
  Future<void> saveProject(Project project) async {
    _replaceById<Project>(_data.projects, project, (item) => item.id);
  }

  @override
  Future<void> saveTask(WorkTask task) async {
    _replaceById<WorkTask>(_data.tasks, task, (item) => item.id);
  }

  @override
  Future<void> softDeleteTask(String taskId, DateTime deletedAt) async {
    final index = _data.tasks.indexWhere((item) => item.id == taskId);
    if (index >= 0) _data.tasks[index].deletedAt = deletedAt;
  }

  @override
  Future<void> saveNote(Note note) async {
    _replaceById<Note>(_data.notes, note, (item) => item.id);
  }

  @override
  Future<void> saveNoteVersion(NoteVersion version) async {
    _replaceById<NoteVersion>(_data.noteVersions, version, (item) => item.id);
  }

  @override
  Future<void> replaceNoteLinks(String noteId, List<NoteLink> links) async {
    _data.noteLinks.removeWhere((link) => link.sourceNoteId == noteId);
    _data.noteLinks.addAll(links);
  }

  @override
  Future<void> saveTimeEntry(TimeEntry entry) async {
    _replaceById<TimeEntry>(_data.entries, entry, (item) => item.id);
  }

  @override
  Future<void> softDeleteNote(String noteId, DateTime deletedAt) async {
    final index = _data.notes.indexWhere((item) => item.id == noteId);
    if (index >= 0) _data.notes[index].deletedAt = deletedAt;
  }

  @override
  Future<void> restoreNote(String noteId) async {
    final index = _data.notes.indexWhere((item) => item.id == noteId);
    if (index >= 0) _data.notes[index].deletedAt = null;
  }

  @override
  Future<void> saveActiveTimer(ActiveTimerState? timer) async {
    _activeTimer = timer;
  }

  @override
  Future<ActiveTimerState?> loadActiveTimer() async => _activeTimer;

  @override
  Future<String> exportJson() async => _data.encode();

  @override
  Future<void> importJson(String raw) async {
    _data = AppData.decode(raw);
    _initialized = true;
  }

  @override
  Future<void> close() async {}

  void _replaceById<T>(List<T> items, T value, String Function(T item) readId) {
    final index = items.indexWhere((item) => readId(item) == readId(value));
    if (index < 0) {
      items.add(value);
    } else {
      items[index] = value;
    }
  }
}
