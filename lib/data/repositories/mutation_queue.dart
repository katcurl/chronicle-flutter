import 'dart:async';

final class MutationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() mutation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await mutation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> drain() => _tail;
}
