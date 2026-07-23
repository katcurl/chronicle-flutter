import 'dart:async';

import 'package:flutter/widgets.dart';

/// Coalesced undo/redo history for a Markdown editor.
///
/// Flutter's native text history is intentionally not relied on here because
/// Chronicle also changes the controller programmatically when inserting
/// templates, images, tables, columns and block operations. This history sees
/// both typed and programmatic edits and preserves the selection with every
/// committed snapshot.
class NoteEditHistory extends ChangeNotifier {
  NoteEditHistory({
    required this.controller,
    this.coalesceDelay = const Duration(milliseconds: 420),
    this.maxEntries = 120,
  }) : assert(maxEntries >= 2) {
    _entries.add(_normalized(controller.value));
    controller.addListener(_handleControllerChanged);
  }

  final TextEditingController controller;
  final Duration coalesceDelay;
  final int maxEntries;

  final List<TextEditingValue> _entries = <TextEditingValue>[];
  Timer? _timer;
  TextEditingValue? _pendingValue;
  int _index = 0;
  bool _applyingHistory = false;

  bool get canUndo => _pendingValue != null || _index > 0;
  bool get canRedo => _pendingValue == null && _index < _entries.length - 1;
  int get committedEntryCount => _entries.length;

  void _handleControllerChanged() {
    if (_applyingHistory) {
      return;
    }

    final next = _normalized(controller.value);
    final current = _pendingValue ?? _entries[_index];
    if (next.text == current.text) {
      if (_pendingValue != null) {
        _pendingValue = next;
      } else {
        _entries[_index] = next;
      }
      return;
    }

    final stateChanged = _pendingValue == null;
    _pendingValue = next;
    _timer?.cancel();
    _timer = Timer(coalesceDelay, flush);
    if (stateChanged) {
      notifyListeners();
    }
  }

  /// Commits the latest burst of edits as one undo step.
  void flush() {
    _timer?.cancel();
    _timer = null;
    final next = _pendingValue;
    if (next == null) {
      return;
    }
    _pendingValue = null;

    if (next.text == _entries[_index].text) {
      _entries[_index] = next;
      notifyListeners();
      return;
    }

    if (_index < _entries.length - 1) {
      _entries.removeRange(_index + 1, _entries.length);
    }
    _entries.add(next);
    _index = _entries.length - 1;

    if (_entries.length > maxEntries) {
      final overflow = _entries.length - maxEntries;
      _entries.removeRange(0, overflow);
      _index -= overflow;
    }
    notifyListeners();
  }

  bool undo() {
    flush();
    if (_index <= 0) {
      return false;
    }
    _index -= 1;
    _apply(_entries[_index]);
    notifyListeners();
    return true;
  }

  bool redo() {
    if (_pendingValue != null || _index >= _entries.length - 1) {
      return false;
    }
    _index += 1;
    _apply(_entries[_index]);
    notifyListeners();
    return true;
  }

  /// Starts a new history session from the controller's current value.
  ///
  /// Used after restoring an old note version or reloading the note after a
  /// rename, where undoing into the previous document would be surprising.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _pendingValue = null;
    _entries
      ..clear()
      ..add(_normalized(controller.value));
    _index = 0;
    notifyListeners();
  }

  void _apply(TextEditingValue value) {
    _applyingHistory = true;
    try {
      controller.value = _normalized(value);
    } finally {
      _applyingHistory = false;
    }
  }

  TextEditingValue _normalized(TextEditingValue value) {
    final textLength = value.text.length;
    final selection = value.selection;
    final normalizedSelection =
        selection.isValid
            ? TextSelection(
              baseOffset: selection.baseOffset.clamp(0, textLength).toInt(),
              extentOffset: selection.extentOffset.clamp(0, textLength).toInt(),
              affinity: selection.affinity,
              isDirectional: selection.isDirectional,
            )
            : TextSelection.collapsed(offset: textLength);
    return value.copyWith(
      selection: normalizedSelection,
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    controller.removeListener(_handleControllerChanged);
    super.dispose();
  }
}
