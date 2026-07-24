import 'package:chronicle/application/sync/sync_coordinator.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync coordinator bootstraps and compacts journal state', () async {
    final data = AppData(
      projects: <Project>[Project(id: 'project', title: 'Project', emoji: 'P')],
      tasks: <WorkTask>[],
      notes: <Note>[],
      entries: <TimeEntry>[],
    );
    final repository = InMemoryAppRepository(initialData: data);
    await repository.markInitialized();
    var notifications = 0;
    final coordinator = SyncCoordinator(
      repository: repository,
      currentData: () => data,
      replaceData: (_) {},
      rebuildAllNoteLinks: () async {},
      scheduleVaultMirror: () {},
      onAttachmentRefresh: () {},
      recordReliability:
          ({
            required stage,
            required level,
            required message,
            peerDeviceId,
            details = const <String, Object?>{},
          }) async {},
      notifyListeners: () => notifications++,
    );

    await coordinator.refreshFoundation();

    expect(coordinator.deviceIdentity, isNotNull);
    expect(coordinator.journalEntryCount, 1);
    expect(coordinator.recentChanges, hasLength(1));
    expect(notifications, 1);
  });
}
