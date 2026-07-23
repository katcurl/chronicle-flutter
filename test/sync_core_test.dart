import 'dart:convert';

import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync journal batch survives JSON round-trip', () {
    final change = _change(
      changeId: 'change-json',
      entityType: 'project',
      entityId: 'project-json',
      revision: 3,
      changedAt: DateTime.utc(2026, 7, 16, 12),
      payload:
          Project(
            id: 'project-json',
            title: 'JSON project',
            emoji: '🧪',
          ).toJson(),
    );
    final batch = SyncJournalBatch(
      afterSequence: 4,
      throughSequence: 8,
      changes: [change],
      hasMore: true,
    );

    final restored = SyncJournalBatch.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(batch.toJson())) as Map),
    );

    expect(restored.afterSequence, 4);
    expect(restored.throughSequence, 8);
    expect(restored.hasMore, isTrue);
    expect(restored.changes.single.changeId, change.changeId);
    expect(restored.changes.single.payload['title'], 'JSON project');
  });

  test(
    'remote changes are idempotent and are not echoed to their origin',
    () async {
      final source = InMemoryAppRepository();
      final target = InMemoryAppRepository();
      final sourceIdentity = await source.ensureDeviceIdentity();
      final targetIdentity = await target.ensureDeviceIdentity();

      await source.saveProject(
        Project(id: 'project-remote', title: 'Remote project', emoji: '🔄'),
      );
      final outgoing = await source.loadOutgoingChanges(
        peerDeviceId: targetIdentity.deviceId,
        afterSequence: 0,
      );

      final first = await target.applyRemoteChanges(outgoing.changes);
      final second = await target.applyRemoteChanges(outgoing.changes);
      final restored = await target.load();
      final echo = await target.loadOutgoingChanges(
        peerDeviceId: sourceIdentity.deviceId,
        afterSequence: 0,
      );

      expect(first.insertedCount, 1);
      expect(first.appliedCount, 1);
      expect(second.insertedCount, 0);
      expect(second.duplicateCount, 1);
      expect(restored.projects.single.title, 'Remote project');
      expect(echo.changes, isEmpty);
      expect(echo.throughSequence, 1);
    },
  );

  test(
    'newer deterministic winner is not replaced by a stale conflict',
    () async {
      final repository = InMemoryAppRepository();
      final newer = _change(
        changeId: 'winner-b',
        entityType: 'project',
        entityId: 'project-conflict',
        revision: 2,
        changedAt: DateTime.utc(2026, 7, 16, 12, 1),
        payload:
            Project(
              id: 'project-conflict',
              title: 'Новая версия',
              emoji: '🟢',
            ).toJson(),
      );
      final older = _change(
        changeId: 'winner-a',
        entityType: 'project',
        entityId: 'project-conflict',
        revision: 2,
        changedAt: DateTime.utc(2026, 7, 16, 12),
        payload:
            Project(
              id: 'project-conflict',
              title: 'Старая версия',
              emoji: '🟡',
            ).toJson(),
      );

      await repository.applyRemoteChanges([newer]);
      final staleResult = await repository.applyRemoteChanges([older]);
      final restored = await repository.load();

      expect(staleResult.insertedCount, 1);
      expect(staleResult.appliedCount, 0);
      expect(staleResult.staleCount, 1);
      expect(restored.projects.single.title, 'Новая версия');
    },
  );

  test(
    'remote tombstone removes a note without creating a local echo',
    () async {
      final repository = InMemoryAppRepository();
      const originDeviceId = 'phone-origin';
      final project = Project(
        id: 'project-delete',
        title: 'Delete test',
        emoji: '🗑️',
      );
      final note = Note(
        id: 'note-delete',
        title: 'Удаляемая заметка',
        projectId: project.id,
        body: 'Черновик',
      );

      final result = await repository.applyRemoteChanges([
        _change(
          changeId: 'project-upsert',
          entityType: 'project',
          entityId: project.id,
          revision: 1,
          changedAt: DateTime.utc(2026, 7, 16, 10),
          payload: project.toJson(),
          originDeviceId: originDeviceId,
        ),
        _change(
          changeId: 'note-delete-2',
          entityType: 'note',
          entityId: note.id,
          operation: 'delete',
          revision: 2,
          changedAt: DateTime.utc(2026, 7, 16, 10, 2),
          payload: {
            'deletedAt': DateTime.utc(2026, 7, 16, 10, 2).toIso8601String(),
          },
          originDeviceId: originDeviceId,
        ),
        _change(
          changeId: 'note-upsert-1',
          entityType: 'note',
          entityId: note.id,
          revision: 1,
          changedAt: DateTime.utc(2026, 7, 16, 10, 1),
          payload: note.toJson(),
          originDeviceId: originDeviceId,
        ),
      ]);
      final restored = await repository.load();
      final outgoing = await repository.loadOutgoingChanges(
        peerDeviceId: originDeviceId,
        afterSequence: 0,
      );

      expect(result.appliedCount, 3);
      expect(restored.projects, hasLength(1));
      expect(restored.notes, isEmpty);
      expect(outgoing.changes, isEmpty);
      expect(outgoing.throughSequence, 3);
    },
  );

  test(
    'outgoing cursor advances across filtered peer-origin records',
    () async {
      final repository = InMemoryAppRepository();
      const peerDeviceId = 'peer-device';
      await repository.applyRemoteChanges([
        _change(
          changeId: 'peer-change-1',
          entityType: 'project',
          entityId: 'peer-project',
          revision: 1,
          changedAt: DateTime.utc(2026, 7, 16, 9),
          payload:
              Project(
                id: 'peer-project',
                title: 'Peer project',
                emoji: '📱',
              ).toJson(),
          originDeviceId: peerDeviceId,
        ),
      ]);

      final batch = await repository.loadOutgoingChanges(
        peerDeviceId: peerDeviceId,
        afterSequence: 0,
        limit: 50,
      );

      expect(batch.changes, isEmpty);
      expect(batch.throughSequence, 1);
      expect(batch.hasMore, isFalse);
    },
  );
}

ChangeRecord _change({
  required String changeId,
  required String entityType,
  required String entityId,
  required int revision,
  required DateTime changedAt,
  required Map<String, dynamic> payload,
  String operation = 'upsert',
  String originDeviceId = 'remote-device',
}) {
  return ChangeRecord(
    localSequence: revision,
    changeId: changeId,
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    revision: revision,
    originDeviceId: originDeviceId,
    changedAt: changedAt,
    payloadJson: jsonEncode(payload),
  );
}
