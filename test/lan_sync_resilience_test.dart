import 'package:flutter_test/flutter_test.dart';

import 'package:chronicle/sync/lan_sync_resilience.dart';

void main() {
  test('cancellation token stops an operation before it starts', () async {
    final token = LanSyncCancellationToken()..cancel();
    var called = false;

    await expectLater(
      runLanSyncOperationWithRetry<void>(
        operation: (_) async {
          called = true;
        },
        shouldRetry: (_) => true,
        cancellationToken: token,
      ),
      throwsA(isA<LanSyncCancelledException>()),
    );
    expect(called, isFalse);
  });

  test('only the failed operation is retried', () async {
    var attempts = 0;
    final retries = <int>[];

    final result = await runLanSyncOperationWithRetry<String>(
      operation: (attempt) async {
        attempts += 1;
        if (attempt < 3) {
          throw StateError('temporary connection reset');
        }
        return 'ok';
      },
      shouldRetry: (error) => error.toString().contains('connection reset'),
      onRetry: (nextAttempt, _) => retries.add(nextAttempt),
      baseDelay: Duration.zero,
      delay: (_) async {},
    );

    expect(result, 'ok');
    expect(attempts, 3);
    expect(retries, <int>[2, 3]);
  });

  test('cancellation interrupts the retry wait', () async {
    final token = LanSyncCancellationToken();
    var attempts = 0;

    await expectLater(
      runLanSyncOperationWithRetry<void>(
        operation: (_) async {
          attempts += 1;
          throw StateError('temporary connection reset');
        },
        shouldRetry: (_) => true,
        cancellationToken: token,
        onRetry: (_, __) => token.cancel(),
        baseDelay: Duration.zero,
      ),
      throwsA(isA<LanSyncCancelledException>()),
    );
    expect(attempts, 1);
  });
}
