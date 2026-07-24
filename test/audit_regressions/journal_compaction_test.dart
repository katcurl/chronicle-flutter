import 'dart:convert';

import 'package:chronicle/data/database/chronicle_database.dart';
import 'package:chronicle/data/repositories/drift_app_repository.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/sync/sync_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'one hundred large note saves collapse below the payload budget',
    () async {
      final database = ChronicleDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftAppRepository(
        database: database,
        automaticJournalMaxEntries: 1000000,
        automaticJournalMaxPayloadBytes: 1024 * 1024 * 1024,
      );
      final project = Project(id: 'project', title: 'Project', emoji: '🧪');
      final note = Note(
        id: 'large-note',
        title: 'Large',
        projectId: project.id,
        body: List<String>.filled(1024 * 1024, 'x').join(),
      );
      await repository.saveProject(project);

      for (var revision = 1; revision <= 100; revision++) {
        note.revision = revision;
        note.updatedAt = DateTime.utc(2026, 7, 24, 10, 0, revision);
        await repository.saveNote(note);
      }

      final result = await repository.compactJournal(
        maxEntries: 50000,
        maxPayloadBytes: 10 * 1024 * 1024,
      );

      expect(result.didCompact, isTrue);
      expect(result.payloadBytesBefore, greaterThan(90 * 1024 * 1024));
      expect(result.payloadBytesAfter, lessThan(10 * 1024 * 1024));
      expect(result.entryCountAfter, 2);
    },
  );

  test(
    'compaction preserves cursor semantics for old, current and new peers',
    () async {
      final repository = InMemoryAppRepository(
        automaticJournalMaxEntries: 1000000,
        automaticJournalMaxPayloadBytes: 1024 * 1024 * 1024,
      );
      final first = await repository.recordLocalChange(
        entityType: 'project',
        entityId: 'project',
        operation: 'upsert',
        payload: Project(id: 'project', title: 'v1', emoji: '1').toJson(),
      );
      final second = await repository.recordLocalChange(
        entityType: 'project',
        entityId: 'project',
        operation: 'upsert',
        payload: Project(id: 'project', title: 'v2', emoji: '2').toJson(),
      );
      await repository.saveSyncCursor(
        SyncCursor(
          peerDeviceId: 'old-peer',
          lastSentSequence: first.localSequence,
        ),
      );
      await repository.saveSyncCursor(
        SyncCursor(
          peerDeviceId: 'current-peer',
          lastSentSequence: second.localSequence,
        ),
      );

      final firstCompaction = await repository.compactJournal(
        maxEntries: 1,
        maxPayloadBytes: 1024 * 1024,
      );
      final oldPeer = await repository.loadOutgoingChanges(
        peerDeviceId: 'old-peer',
        afterSequence: first.localSequence,
      );
      final currentPeer = await repository.loadOutgoingChanges(
        peerDeviceId: 'current-peer',
        afterSequence: second.localSequence,
      );
      final newPeer = await repository.loadOutgoingChanges(
        peerDeviceId: 'new-peer',
        afterSequence: 0,
      );
      final secondCompaction = await repository.compactJournal(
        maxEntries: 1,
        maxPayloadBytes: 1024 * 1024,
      );

      expect(firstCompaction.didCompact, isTrue);
      expect(firstCompaction.minimumPeerCursor, first.localSequence);
      expect(oldPeer.changes.single.payload['title'], 'v2');
      expect(currentPeer.changes, isEmpty);
      expect(newPeer.changes.single.payload['title'], 'v2');
      expect(secondCompaction.didCompact, isFalse);
      expect(secondCompaction.generation, firstCompaction.generation);
    },
  );

  test('compacted tombstone blocks stale resurrection on a new peer', () async {
    final source = InMemoryAppRepository(
      automaticJournalMaxEntries: 1000000,
      automaticJournalMaxPayloadBytes: 1024 * 1024 * 1024,
    );
    final project = Project(id: 'project', title: 'Project', emoji: '🪦');
    final note = Note(
      id: 'note',
      title: 'Deleted',
      projectId: project.id,
      body: 'old',
    );
    await source.saveProject(project);
    final staleUpsert = await source.recordLocalChange(
      entityType: 'note',
      entityId: note.id,
      operation: 'upsert',
      payload: note.toJson(),
    );
    await source.softDeleteNote(note.id, DateTime.utc(2026, 7, 24, 12));

    await source.compactJournal(maxEntries: 1, maxPayloadBytes: 1024 * 1024);
    final compacted = await source.loadOutgoingChanges(
      peerDeviceId: 'new-peer',
      afterSequence: 0,
    );
    final target = InMemoryAppRepository();
    await target.applyRemoteChanges(compacted.changes);
    final staleResult = await target.applyRemoteChanges([staleUpsert]);

    expect((await target.load()).notes, isEmpty);
    expect(
      compacted.changes
          .where((change) => change.entityType == 'note')
          .single
          .operation,
      'delete',
    );
    expect(staleResult.staleCount, 1);
    expect((await target.load()).notes, isEmpty);
  });

  test('restore winner becomes a complete snapshot for a new peer', () async {
    final source = InMemoryAppRepository(
      automaticJournalMaxEntries: 1000000,
      automaticJournalMaxPayloadBytes: 1024 * 1024 * 1024,
    );
    final project = Project(id: 'project', title: 'Project', emoji: '♻️');
    final note = Note(
      id: 'note',
      title: 'Restored',
      projectId: project.id,
      body: 'complete body',
    );
    await source.saveProject(project);
    await source.saveNote(note);
    await source.softDeleteNote(note.id, DateTime.utc(2026, 7, 24, 12));
    await source.restoreNote(note.id);

    await source.compactJournal(maxEntries: 1, maxPayloadBytes: 1024 * 1024);
    final batch = await source.loadOutgoingChanges(
      peerDeviceId: 'new-peer',
      afterSequence: 0,
    );
    final noteChange =
        batch.changes.where((change) => change.entityType == 'note').single;
    final target = InMemoryAppRepository();
    await target.applyRemoteChanges(batch.changes);

    expect(noteChange.operation, 'snapshot');
    expect(noteChange.payload['body'], 'complete body');
    expect((await target.load()).notes.single.body, 'complete body');
  });

  test(
    'automatic SQLite compaction persists metrics and monotonic sequence',
    () async {
      final database = ChronicleDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var repository = DriftAppRepository(
        database: database,
        automaticJournalMaxEntries: 2,
        automaticJournalMaxPayloadBytes: 1024 * 1024,
      );
      final project = Project(id: 'project', title: 'v1', emoji: '🗜️');
      await repository.saveProject(project);
      project.title = 'v2';
      await repository.saveProject(project);
      project.title = 'v3';
      await repository.saveProject(project);

      var batch = await repository.loadOutgoingChanges(
        peerDeviceId: 'new-peer',
        afterSequence: 0,
      );
      expect(batch.changes.single.localSequence, 3);
      expect(batch.changes.single.payload['title'], 'v3');

      repository = DriftAppRepository(
        database: database,
        automaticJournalMaxEntries: 2,
        automaticJournalMaxPayloadBytes: 1024 * 1024,
      );
      project.title = 'v4';
      await repository.saveProject(project);
      project.title = 'v5';
      await repository.saveProject(project);

      batch = await repository.loadOutgoingChanges(
        peerDeviceId: 'existing-peer',
        afterSequence: 3,
      );
      final diagnostics = await repository.compactJournal(
        maxEntries: 2,
        maxPayloadBytes: 1024 * 1024,
      );

      expect(batch.changes.single.localSequence, 5);
      expect(batch.changes.single.payload['title'], 'v5');
      expect(diagnostics.didCompact, isFalse);
      expect(diagnostics.generation, 2);
      expect(diagnostics.lastCompactedSequence, 5);
    },
  );

  test(
    'SQLite compaction canonicalizes restore into a full snapshot',
    () async {
      final database = ChronicleDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftAppRepository(
        database: database,
        automaticJournalMaxEntries: 1000000,
        automaticJournalMaxPayloadBytes: 1024 * 1024 * 1024,
      );
      final project = Project(id: 'project', title: 'Project', emoji: '♻️');
      final note = Note(
        id: 'note',
        title: 'Restored',
        projectId: project.id,
        body: 'SQLite body',
      );
      await repository.saveProject(project);
      await repository.saveNote(note);
      await repository.softDeleteNote(note.id, DateTime.utc(2026, 7, 24, 12));
      await repository.restoreNote(note.id);

      await repository.compactJournal(
        maxEntries: 1,
        maxPayloadBytes: 1024 * 1024,
      );
      final batch = await repository.loadOutgoingChanges(
        peerDeviceId: 'new-peer',
        afterSequence: 0,
      );
      final noteChange =
          batch.changes.where((change) => change.entityType == 'note').single;
      final target = InMemoryAppRepository();
      await target.applyRemoteChanges(batch.changes);

      expect(noteChange.operation, 'snapshot');
      expect(noteChange.payload['body'], 'SQLite body');
      expect((await target.load()).notes.single.body, 'SQLite body');
    },
  );

  test(
    'SQLite compaction keeps the exact microsecond freshness winner',
    () async {
      final database = ChronicleDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftAppRepository(
        database: database,
        automaticJournalMaxEntries: 1000000,
        automaticJournalMaxPayloadBytes: 1024 * 1024 * 1024,
      );
      final earlier = DateTime.utc(2026, 7, 24, 12, 0, 0, 0, 1);
      final later = earlier.add(const Duration(microseconds: 1));
      ChangeRecord remote({
        required String changeId,
        required DateTime changedAt,
        required String title,
      }) {
        final project = Project(id: 'project', title: title, emoji: '⏱️');
        return ChangeRecord(
          localSequence: 0,
          changeId: changeId,
          entityType: 'project',
          entityId: project.id,
          operation: 'upsert',
          revision: 1,
          originDeviceId: 'remote',
          changedAt: changedAt,
          payloadJson: jsonEncode(project.toJson()),
        );
      }

      await repository.applyRemoteChanges([
        remote(changeId: 'z-earlier', changedAt: earlier, title: 'earlier'),
        remote(changeId: 'a-later', changedAt: later, title: 'later'),
      ]);
      await repository.compactJournal(
        maxEntries: 1,
        maxPayloadBytes: 1024 * 1024,
      );
      final batch = await repository.loadOutgoingChanges(
        peerDeviceId: 'new-peer',
        afterSequence: 0,
      );

      expect(batch.changes.single.payload['title'], 'later');
    },
  );
}
