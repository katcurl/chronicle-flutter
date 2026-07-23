import 'dart:async';

import 'package:flutter/foundation.dart';

/// A text notifier that coalesces rapid editor changes before rebuilding
/// expensive listeners such as Markdown preview and note statistics.
class DebouncedTextNotifier extends ValueNotifier<String> {
  DebouncedTextNotifier(super.value, {required this.delay});

  final Duration delay;

  Timer? _timer;
  String? _pendingValue;
  bool _paused = false;

  bool get hasPendingValue => _pendingValue != null;

  void schedule(String nextValue) {
    if (_pendingValue == nextValue ||
        (_pendingValue == null && value == nextValue)) {
      return;
    }
    _pendingValue = nextValue;
    _timer?.cancel();
    _timer = null;
    if (_paused) {
      return;
    }
    _timer = Timer(delay, flush);
  }

  void setImmediate(String nextValue) {
    _paused = false;
    _timer?.cancel();
    _timer = null;
    _pendingValue = null;
    value = nextValue;
  }

  void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  void resume({bool immediate = false}) {
    if (!_paused) {
      if (immediate) {
        flush();
      }
      return;
    }
    _paused = false;
    if (_pendingValue == null) {
      return;
    }
    if (immediate) {
      flush();
      return;
    }
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_paused) {
      return;
    }
    final nextValue = _pendingValue;
    _pendingValue = null;
    if (nextValue != null) {
      value = nextValue;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
