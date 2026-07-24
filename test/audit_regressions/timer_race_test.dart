import 'dart:async';

import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/features/timer/timer_duration.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_vault_backend.dart';

void main() {
  test('concurrent timer stops append exactly one entry', () async {
    final repository = _BlockingTimerRepository(initialData: _initialData());
    await repository.markInitialized();
    final store = _store(repository);
    addTearDown(() {
      if (!repository.saveCompleter.isCompleted) {
        repository.saveCompleter.complete();
      }
      store.dispose();
    });
    await store.load();
    await store.startTimer(description: 'Focus', projectId: 'p');

    final first = Function.apply(store.stopTimer, const []);
    final second = Function.apply(store.stopTimer, const []);

    expect(first, isA<Future<void>>());
    expect(second, isA<Future<void>>());
    repository.saveCompleter.complete();
    await Future.wait<void>([first as Future<void>, second as Future<void>]);

    expect(repository.appendCalls, 1);
    expect(store.data.entries, hasLength(1));
    expect(store.activeStartedAt, isNull);
  });

  test('secondsWithinDay intersects sessions with calendar days', () {
    final startedAt = DateTime(2026, 7, 24, 23, 59, 30);

    expect(
      secondsWithinDay(
        startedAt: startedAt,
        durationSeconds: 90,
        day: DateTime(2026, 7, 24),
      ),
      30,
    );
    expect(
      secondsWithinDay(
        startedAt: startedAt,
        durationSeconds: 90,
        day: DateTime(2026, 7, 25),
      ),
      60,
    );
    expect(
      secondsWithinDay(
        startedAt: startedAt,
        durationSeconds: 0,
        day: DateTime(2026, 7, 24),
      ),
      0,
    );
  });

  test('elapsedTimerSeconds never returns a negative duration', () {
    final startedAt = DateTime(2026, 7, 24, 12);

    expect(
      elapsedTimerSeconds(
        startedAt: startedAt,
        endedAt: startedAt.subtract(const Duration(minutes: 1)),
      ),
      0,
    );
  });
}

AppStore _store(InMemoryAppRepository repository) => AppStore(
  repository: repository,
  vaultService: VaultService(backend: TestVaultBackend()),
);

AppData _initialData() => AppData(
  projects: [Project(id: 'p', title: 'Project', emoji: '📌')],
  tasks: <WorkTask>[],
  notes: <Note>[],
  entries: <TimeEntry>[],
);

final class _BlockingTimerRepository extends InMemoryAppRepository {
  _BlockingTimerRepository({required super.initialData});

  final Completer<void> saveCompleter = Completer<void>();
  int appendCalls = 0;

  @override
  Future<void> appendTimeEntryAndClearTimer(TimeEntry entry) async {
    appendCalls += 1;
    await saveCompleter.future;
    await super.appendTimeEntryAndClearTimer(entry);
  }
}
