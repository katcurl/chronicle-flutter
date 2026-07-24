import '../../models/app_models.dart';

abstract interface class DomainMutationRepository {
  Future<void> appendTimeEntryAndClearTimer(TimeEntry entry);

  Future<void> deleteTaskGraph(String taskId, DateTime deletedAt);

  Future<void> deleteNoteGraph(String noteId, DateTime deletedAt);
}
