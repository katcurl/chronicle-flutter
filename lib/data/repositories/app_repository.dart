import '../../models/app_models.dart';

abstract class AppRepository {
  Future<bool> isInitialized();

  Future<void> markInitialized();

  Future<AppData> load();

  Future<void> replaceAll(AppData data);

  Future<void> saveProject(Project project);

  Future<void> saveTask(WorkTask task);

  Future<void> softDeleteTask(String taskId, DateTime deletedAt);

  Future<void> saveNote(Note note);

  Future<void> saveNoteVersion(NoteVersion version);

  Future<void> replaceNoteLinks(String noteId, List<NoteLink> links);

  Future<void> saveTimeEntry(TimeEntry entry);

  Future<void> softDeleteNote(String noteId, DateTime deletedAt);

  Future<void> restoreNote(String noteId);

  Future<void> saveActiveTimer(ActiveTimerState? timer);

  Future<ActiveTimerState?> loadActiveTimer();

  Future<String> exportJson();

  Future<void> importJson(String raw);

  Future<void> close();
}
