enum StagedRestorePhase { staged, committing, committed }

enum RestoreCutPoint {
  afterStaged,
  afterCommittingMarker,
  afterDatabaseCommit,
  afterAttachmentCommit,
  afterCommittedMarker,
}

typedef RestoreCutPointCallback = Future<void> Function(RestoreCutPoint point);

final class RestoreInterruption implements Exception {
  const RestoreInterruption(this.point);

  final RestoreCutPoint point;

  @override
  String toString() => 'Restore interrupted at ${point.name}';
}

final class StagedRestoreMarker {
  StagedRestoreMarker({
    required this.restoreId,
    required this.phase,
    required this.oldGeneration,
    required this.newGeneration,
    required this.oldAttachmentsExisted,
    required this.oldAttachmentIndexExisted,
    required Map<String, String> expectedSha256ByPath,
  }) : expectedSha256ByPath = Map<String, String>.unmodifiable(
         expectedSha256ByPath,
       );

  final String restoreId;
  final StagedRestorePhase phase;
  final String oldGeneration;
  final String newGeneration;
  final bool oldAttachmentsExisted;
  final bool oldAttachmentIndexExisted;
  final Map<String, String> expectedSha256ByPath;

  StagedRestoreMarker copyWith({StagedRestorePhase? phase}) {
    return StagedRestoreMarker(
      restoreId: restoreId,
      phase: phase ?? this.phase,
      oldGeneration: oldGeneration,
      newGeneration: newGeneration,
      oldAttachmentsExisted: oldAttachmentsExisted,
      oldAttachmentIndexExisted: oldAttachmentIndexExisted,
      expectedSha256ByPath: expectedSha256ByPath,
    );
  }

  Map<String, Object?> toJson() => {
    'format': 'chronicle-staged-restore',
    'version': 1,
    'restoreId': restoreId,
    'phase': phase.name,
    'oldGeneration': oldGeneration,
    'newGeneration': newGeneration,
    'oldAttachmentsExisted': oldAttachmentsExisted,
    'oldAttachmentIndexExisted': oldAttachmentIndexExisted,
    'expectedSha256ByPath': expectedSha256ByPath,
  };

  factory StagedRestoreMarker.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'chronicle-staged-restore' ||
        json['version'] != 1 ||
        json['restoreId'] is! String ||
        json['oldGeneration'] is! String ||
        json['newGeneration'] is! String ||
        json['oldAttachmentsExisted'] is! bool ||
        json['oldAttachmentIndexExisted'] is! bool ||
        json['expectedSha256ByPath'] is! Map) {
      throw const FormatException('Некорректный маркер восстановления.');
    }
    final restoreId = json['restoreId']! as String;
    final oldGeneration = json['oldGeneration']! as String;
    final newGeneration = json['newGeneration']! as String;
    if (!_safeIdentifier(restoreId) ||
        !_safeIdentifier(oldGeneration) ||
        !_safeIdentifier(newGeneration)) {
      throw const FormatException(
        'Маркер восстановления содержит небезопасный идентификатор.',
      );
    }
    StagedRestorePhase? phase;
    for (final candidate in StagedRestorePhase.values) {
      if (candidate.name == json['phase']) {
        phase = candidate;
        break;
      }
    }
    if (phase == null) {
      throw const FormatException(
        'Маркер восстановления содержит неизвестную фазу.',
      );
    }
    final hashes = <String, String>{};
    for (final entry in (json['expectedSha256ByPath']! as Map).entries) {
      final path = entry.key.toString();
      final hash = entry.value?.toString() ?? '';
      if ((!path.startsWith('Attachments/') &&
              path != '.chronicle/attachments-index.json') ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
        throw const FormatException(
          'Маркер восстановления содержит неверную контрольную сумму.',
        );
      }
      hashes[path] = hash;
    }
    if (!hashes.containsKey('.chronicle/attachments-index.json')) {
      throw const FormatException(
        'Маркер восстановления не содержит хеш индекса вложений.',
      );
    }
    return StagedRestoreMarker(
      restoreId: restoreId,
      phase: phase,
      oldGeneration: oldGeneration,
      newGeneration: newGeneration,
      oldAttachmentsExisted: json['oldAttachmentsExisted']! as bool,
      oldAttachmentIndexExisted: json['oldAttachmentIndexExisted']! as bool,
      expectedSha256ByPath: hashes,
    );
  }
}

bool _safeIdentifier(String value) =>
    value.isNotEmpty && RegExp(r'^[A-Za-z0-9-]{1,128}$').hasMatch(value);
