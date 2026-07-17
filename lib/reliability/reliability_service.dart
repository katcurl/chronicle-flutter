import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'reliability_backend.dart';
import 'reliability_models.dart';

class ReliabilityService {
  ReliabilityService({ReliabilityBackend? backend})
    : _backend = backend ?? ReliabilityBackend();

  static const String _eventsKey = 'chronicle_reliability_events_v1';
  static const String _lastBackupAtKey =
      'chronicle_reliability_last_backup_at_v1';
  static const String _lastBackupPathKey =
      'chronicle_reliability_last_backup_path_v1';
  static const int maxEventCount = 120;

  final ReliabilityBackend _backend;
  final List<ReliabilityEvent> _events = <ReliabilityEvent>[];
  int _idCounter = 0;

  List<ReliabilityEvent> get events =>
      List<ReliabilityEvent>.unmodifiable(_events.reversed);

  DateTime? lastAutomaticBackupAt;
  String? lastAutomaticBackupPath;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _events.clear();
    final raw = preferences.getString(_eventsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            final normalized = <String, Object?>{};
            for (final entry in item.entries) {
              normalized[entry.key.toString()] = entry.value;
            }
            final event = ReliabilityEvent.fromJson(normalized);
            if (event.id.isNotEmpty && event.message.isNotEmpty) {
              _events.add(event);
            }
          }
        }
      } on Object {
        _events.clear();
      }
    }
    if (_events.length > maxEventCount) {
      _events.removeRange(0, _events.length - maxEventCount);
    }
    lastAutomaticBackupAt = DateTime.tryParse(
      preferences.getString(_lastBackupAtKey) ?? '',
    );
    lastAutomaticBackupPath = preferences.getString(_lastBackupPathKey);
  }

  Future<void> record({
    required ReliabilityStage stage,
    required ReliabilityLevel level,
    required String message,
    String? peerDeviceId,
    Map<String, Object?> details = const <String, Object?>{},
  }) async {
    final now = DateTime.now().toUtc();
    _idCounter++;
    _events.add(
      ReliabilityEvent(
        id: '${now.microsecondsSinceEpoch}-$_idCounter',
        occurredAt: now,
        stage: stage,
        level: level,
        message: _cleanText(message, 500),
        peerDeviceId: _cleanOptional(peerDeviceId, 160),
        details: _cleanDetails(details),
      ),
    );
    if (_events.length > maxEventCount) {
      _events.removeRange(0, _events.length - maxEventCount);
    }
    await _persistEvents();
  }

  bool automaticBackupDue({
    DateTime? now,
    Duration interval = const Duration(hours: 24),
  }) {
    final previous = lastAutomaticBackupAt;
    if (previous == null) {
      return true;
    }
    return (now ?? DateTime.now()).toUtc().difference(previous.toUtc()) >=
        interval;
  }

  Future<void> markAutomaticBackup({
    required DateTime createdAt,
    required String path,
  }) async {
    lastAutomaticBackupAt = createdAt.toUtc();
    lastAutomaticBackupPath = path;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lastBackupAtKey,
      lastAutomaticBackupAt!.toIso8601String(),
    );
    await preferences.setString(_lastBackupPathKey, path);
  }

  Future<void> clearEvents() async {
    _events.clear();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_eventsKey);
  }

  Future<String?> exportDiagnosticReport({
    required Map<String, Object?> snapshot,
  }) async {
    final createdAt = DateTime.now().toUtc();
    final payload = <String, Object?>{
      'format': 'chronicle-diagnostic-report',
      'formatVersion': 1,
      'createdAt': createdAt.toIso8601String(),
      'privacy':
          'The report contains technical events and counters only. Note and task contents are excluded.',
      'snapshot': _cleanDetails(snapshot),
      'events': events.map((event) => event.toJson()).toList(growable: false),
    };
    final raw = const JsonEncoder.withIndent('  ').convert(payload);
    final stamp = createdAt
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return _backend.saveDiagnosticReport(
      fileName: 'chronicle-diagnostics-$stamp.json',
      contents: raw,
    );
  }

  Future<void> _persistEvents() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _eventsKey,
      jsonEncode(_events.map((event) => event.toJson()).toList()),
    );
  }

  Map<String, Object?> _cleanDetails(Map<String, Object?> source) {
    final result = <String, Object?>{};
    for (final entry in source.entries.take(24)) {
      final key = _cleanText(entry.key, 80);
      final value = entry.value;
      if (value == null || value is num || value is bool) {
        result[key] = value;
      } else if (value is DateTime) {
        result[key] = value.toUtc().toIso8601String();
      } else if (value is Iterable) {
        result[key] = value
            .take(20)
            .map((item) => _cleanText(item.toString(), 200))
            .toList(growable: false);
      } else {
        result[key] = _cleanText(value.toString(), 500);
      }
    }
    return result;
  }

  String _cleanText(String value, int maxLength) {
    final normalized = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}…';
  }

  String? _cleanOptional(String? value, int maxLength) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return _cleanText(value, maxLength);
  }
}
