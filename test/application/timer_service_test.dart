import 'dart:io';

import 'package:chronicle/application/timer/timer_service.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/data/repositories/mutation_queue.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'timer persists before publishing state and double-stop is idempotent',
    () async {
      final repository = InMemoryAppRepository();
      final entries = <TimeEntry>[];
      var notifications = 0;
      var syncSchedules = 0;
      final service = TimerService(
        repository: repository,
        mutationQueue: MutationQueue(),
        entries: () => entries,
        now: () => DateTime.utc(2026, 7, 24, 12),
        onStateChanged: () => notifications++,
        onEntrySaved: () => syncSchedules++,
      );
      addTearDown(service.dispose);

      await service.start(description: 'Focus', projectId: 'project');
      expect(service.activeProjectId, 'project');
      expect((await repository.loadActiveTimer())?.description, 'Focus');

      await Future.wait(<Future<void>>[service.stop(), service.stop()]);

      expect(entries, hasLength(1));
      expect((await repository.load()).entries, hasLength(1));
      expect(await repository.loadActiveTimer(), isNull);
      expect(service.activeStartedAt, isNull);
      expect(notifications, 2);
      expect(syncSchedules, 1);
    },
  );

  test('failed stop retains the active timer and in-memory entries', () async {
    final repository = _FailingTimerRepository();
    final entries = <TimeEntry>[];
    final service = TimerService(
      repository: repository,
      mutationQueue: MutationQueue(),
      entries: () => entries,
      now: () => DateTime.utc(2026, 7, 24, 12),
      onStateChanged: () {},
      onEntrySaved: () {},
    );
    addTearDown(service.dispose);
    await service.start(description: 'Focus', projectId: 'project');

    await expectLater(service.stop(), throwsA(isA<FileSystemException>()));

    expect(service.activeProjectId, 'project');
    expect(entries, isEmpty);
    expect((await repository.loadActiveTimer())?.projectId, 'project');
  });
}

final class _FailingTimerRepository extends InMemoryAppRepository {
  @override
  Future<void> appendTimeEntryAndClearTimer(TimeEntry entry) {
    throw const FileSystemException('simulated persistence failure');
  }
}
