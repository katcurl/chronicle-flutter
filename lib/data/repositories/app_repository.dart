import '../../models/app_models.dart';
import '../../sync/pairing_models.dart';
import '../../sync/sync_models.dart';

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

  Future<DeviceIdentity> ensureDeviceIdentity();

  Future<void> saveDeviceIdentity(DeviceIdentity identity);

  Future<DeviceKeyMaterial?> loadDeviceKeyMaterial();

  Future<void> saveDeviceKeyMaterial(DeviceKeyMaterial material);

  Future<List<TrustedDevice>> loadTrustedDevices({bool includeRevoked = false});

  Future<void> saveTrustedDevice(TrustedDevice device);

  Future<void> revokeTrustedDevice(String deviceId, DateTime revokedAt);

  Future<SyncPreferences> loadSyncPreferences();

  Future<void> saveSyncPreferences(SyncPreferences preferences);

  Future<List<ChangeRecord>> loadRecentChanges({int limit = 30});

  Future<int> countJournalEntries();

  Future<bool> isSyncJournalBootstrapped();

  Future<void> markSyncJournalBootstrapped();

  Future<ChangeRecord> recordLocalChange({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  });

  Future<SyncJournalBatch> loadOutgoingChanges({
    required String peerDeviceId,
    required int afterSequence,
    int limit = 200,
  });

  Future<SyncApplyResult> applyRemoteChanges(List<ChangeRecord> changes);

  Future<List<SyncCursor>> loadSyncCursors();

  Future<void> saveSyncCursor(SyncCursor cursor);

  Future<String> exportJson();

  Future<void> importJson(String raw);

  Future<void> close();
}
