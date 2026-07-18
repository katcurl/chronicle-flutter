import 'dart:async';

class LanSyncCancelledException implements Exception {
  const LanSyncCancelledException([this.message = 'Синхронизация отменена.']);

  final String message;

  @override
  String toString() => message;
}

class LanSyncCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw const LanSyncCancelledException();
    }
  }

  Future<void> wait(Duration duration) async {
    throwIfCancelled();
    await Future.any<void>(<Future<void>>[
      Future<void>.delayed(duration),
      whenCancelled,
    ]);
    throwIfCancelled();
  }
}

typedef LanSyncRetryPredicate = bool Function(Object error);
typedef LanSyncRetryCallback = void Function(int nextAttempt, Object error);
typedef LanSyncDelay = Future<void> Function(Duration duration);

Future<T> runLanSyncOperationWithRetry<T>({
  required Future<T> Function(int attempt) operation,
  required LanSyncRetryPredicate shouldRetry,
  LanSyncCancellationToken? cancellationToken,
  LanSyncRetryCallback? onRetry,
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 350),
  LanSyncDelay? delay,
}) async {
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'Must be positive.');
  }

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    cancellationToken?.throwIfCancelled();
    try {
      return await operation(attempt);
    } on Object catch (error) {
      cancellationToken?.throwIfCancelled();
      if (attempt >= maxAttempts || !shouldRetry(error)) {
        rethrow;
      }
      final nextAttempt = attempt + 1;
      onRetry?.call(nextAttempt, error);
      final waitFor = Duration(
        milliseconds: baseDelay.inMilliseconds * attempt,
      );
      if (cancellationToken != null) {
        await cancellationToken.wait(waitFor);
      } else if (delay != null) {
        await delay(waitFor);
      } else {
        await Future<void>.delayed(waitFor);
      }
    }
  }

  throw StateError('Retry loop ended unexpectedly.');
}
