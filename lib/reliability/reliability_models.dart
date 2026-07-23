enum ReliabilityStage {
  startup,
  discovery,
  connection,
  authentication,
  transfer,
  apply,
  backup,
  restore,
  system,
}

enum ReliabilityLevel { info, success, warning, error }

class ReliabilityEvent {
  const ReliabilityEvent({
    required this.id,
    required this.occurredAt,
    required this.stage,
    required this.level,
    required this.message,
    this.peerDeviceId,
    this.details = const <String, Object?>{},
  });

  final String id;
  final DateTime occurredAt;
  final ReliabilityStage stage;
  final ReliabilityLevel level;
  final String message;
  final String? peerDeviceId;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'stage': stage.name,
    'level': level.name,
    'message': message,
    'peerDeviceId': peerDeviceId,
    'details': details,
  };

  factory ReliabilityEvent.fromJson(Map<String, Object?> json) {
    final rawDetails = json['details'];
    final details = <String, Object?>{};
    if (rawDetails is Map) {
      for (final entry in rawDetails.entries) {
        details[entry.key.toString()] = entry.value;
      }
    }
    return ReliabilityEvent(
      id: json['id']?.toString() ?? '',
      occurredAt:
          DateTime.tryParse(json['occurredAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      stage: _enumByName(
        ReliabilityStage.values,
        json['stage']?.toString(),
        ReliabilityStage.system,
      ),
      level: _enumByName(
        ReliabilityLevel.values,
        json['level']?.toString(),
        ReliabilityLevel.info,
      ),
      message: json['message']?.toString() ?? '',
      peerDeviceId: json['peerDeviceId']?.toString(),
      details: details,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}
