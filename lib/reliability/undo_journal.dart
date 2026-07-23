/// One reversible Chronicle operation kept only for the current app session.
///
/// The journal deliberately stores callbacks rather than serializing user data:
/// persistent recovery is handled by note versions, Vault snapshots and
/// portable backups, while this journal covers immediate accidental actions.
class ChronicleUndoEntry {
  ChronicleUndoEntry({
    required this.label,
    required Future<void> Function() restore,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       _restore = restore;

  final String label;
  final DateTime createdAt;
  final Future<void> Function() _restore;
  bool _used = false;

  bool get used => _used;

  Future<void> run() async {
    if (_used) {
      throw StateError('Операция уже была отменена.');
    }
    _used = true;
    try {
      await _restore();
    } on Object {
      _used = false;
      rethrow;
    }
  }
}

class ChronicleUndoJournal {
  ChronicleUndoJournal({this.maxEntries = 20})
    : assert(maxEntries > 0, 'maxEntries must be positive');

  final int maxEntries;
  final List<ChronicleUndoEntry> _entries = <ChronicleUndoEntry>[];

  bool get canUndo => _entries.isNotEmpty;
  int get length => _entries.length;
  String? get nextLabel => _entries.isEmpty ? null : _entries.last.label;

  List<ChronicleUndoEntry> get entries =>
      List<ChronicleUndoEntry>.unmodifiable(_entries.reversed);

  void push(ChronicleUndoEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  Future<String?> undoLast() async {
    if (_entries.isEmpty) {
      return null;
    }
    final entry = _entries.removeLast();
    try {
      await entry.run();
      return entry.label;
    } on Object {
      _entries.add(entry);
      rethrow;
    }
  }

  void clear() => _entries.clear();
}
