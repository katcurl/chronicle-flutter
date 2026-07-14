import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device identity is stable for the same repository', () async {
    final repository = InMemoryAppRepository();

    final first = await repository.ensureDeviceIdentity();
    final second = await repository.ensureDeviceIdentity();

    expect(second.deviceId, first.deviceId);
    expect(second.platform, isNotEmpty);
  });

  test('entity mutations create ordered change records', () async {
    final repository = InMemoryAppRepository();
    final project = Project(
      id: 'project-sync',
      title: 'Sync foundation',
      emoji: '🔄',
    );

    await repository.saveProject(project);
    project.title = 'Sync foundation updated';
    await repository.saveProject(project);

    final changes = await repository.loadRecentChanges();

    expect(await repository.countJournalEntries(), 2);
    expect(changes.first.entityType, 'project');
    expect(changes.first.entityId, project.id);
    expect(changes.first.revision, 2);
    expect(changes.last.revision, 1);
  });

  test('sync preferences remain local and configurable', () async {
    final repository = InMemoryAppRepository();
    const preferences = SyncPreferences(
      autoSyncEnabled: false,
      discoverOnLocalNetwork: true,
      localNetworkOnly: true,
    );

    await repository.saveSyncPreferences(preferences);
    final restored = await repository.loadSyncPreferences();

    expect(restored.autoSyncEnabled, isFalse);
    expect(restored.discoverOnLocalNetwork, isTrue);
    expect(restored.localNetworkOnly, isTrue);
  });
}
