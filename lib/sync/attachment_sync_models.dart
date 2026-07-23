import 'dart:typed_data';

const attachmentSyncManifestVersion = 1;
const maxAttachmentSyncManifestEntries = 10000;
const maxAttachmentSyncEntryBytes = 100 * 1024 * 1024;

typedef BuildAttachmentSyncManifest =
    Future<AttachmentSyncManifest> Function();

typedef ReadAttachmentForSync =
    Future<Uint8List?> Function(AttachmentSyncEntry entry);
typedef StoreAttachmentFromSync =
    Future<AttachmentSyncApplyResult> Function(
      AttachmentSyncEntry entry,
      Uint8List bytes,
    );
typedef ApplyAttachmentRecordFromSync =
    Future<AttachmentSyncApplyResult> Function(AttachmentSyncEntry entry);
typedef ApplyAttachmentTombstoneFromSync =
    Future<AttachmentSyncApplyResult> Function(AttachmentSyncEntry entry);

class AttachmentSyncApplyResult {
  const AttachmentSyncApplyResult({
    required this.changed,
    this.byteLength = 0,
  });

  const AttachmentSyncApplyResult.unchanged()
    : changed = false,
      byteLength = 0;

  final bool changed;
  final int byteLength;
}

class AttachmentSyncEntry {
  const AttachmentSyncEntry({
    required this.relativePath,
    required this.originalName,
    required this.sha256,
    required this.mimeType,
    required this.byteLength,
    required this.createdAt,
    this.deletedAt,
  });

  final String relativePath;
  final String originalName;
  final String sha256;
  final String mimeType;
  final int byteLength;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  bool sameContentAs(AttachmentSyncEntry other) {
    return sha256 == other.sha256 && byteLength == other.byteLength;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'path': relativePath,
    'originalName': originalName,
    'sha256': sha256,
    'mimeType': mimeType,
    'byteLength': byteLength,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  factory AttachmentSyncEntry.fromJson(Map<String, dynamic> json) {
    final relativePath = json['path']?.toString() ?? '';
    final sha256 = json['sha256']?.toString() ?? '';
    final byteLength = _readAttachmentInt(json['byteLength']);
    if (!_validAttachmentPath(relativePath)) {
      throw const FormatException(
        'Attachment manifest contains an invalid path.',
      );
    }
    if (!_validSha256(sha256)) {
      throw const FormatException(
        'Attachment manifest contains an invalid hash.',
      );
    }
    if (byteLength < 0 || byteLength > maxAttachmentSyncEntryBytes) {
      throw const FormatException(
        'Attachment manifest contains an invalid size.',
      );
    }
    return AttachmentSyncEntry(
      relativePath: relativePath,
      originalName: json['originalName']?.toString() ?? '',
      sha256: sha256,
      mimeType:
          json['mimeType']?.toString() ?? 'application/octet-stream',
      byteLength: byteLength,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      deletedAt:
          DateTime.tryParse(json['deletedAt']?.toString() ?? '')?.toUtc(),
    );
  }
}

class AttachmentSyncManifest {
  const AttachmentSyncManifest({
    this.version = attachmentSyncManifestVersion,
    this.generatedAt,
    this.entries = const <AttachmentSyncEntry>[],
  });

  const AttachmentSyncManifest.empty()
    : version = attachmentSyncManifestVersion,
      generatedAt = null,
      entries = const <AttachmentSyncEntry>[];

  final int version;
  final DateTime? generatedAt;
  final List<AttachmentSyncEntry> entries;

  int get activeCount => entries.where((entry) => !entry.isDeleted).length;
  int get tombstoneCount => entries.where((entry) => entry.isDeleted).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'generatedAt': generatedAt?.toUtc().toIso8601String(),
    'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
  };

  factory AttachmentSyncManifest.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    if (rawEntries is! List) {
      return const AttachmentSyncManifest.empty();
    }
    if (rawEntries.length > maxAttachmentSyncManifestEntries) {
      throw const FormatException('Attachment manifest is too large.');
    }
    final entries = <AttachmentSyncEntry>[];
    final paths = <String>{};
    for (final rawEntry in rawEntries) {
      if (rawEntry is! Map) {
        throw const FormatException('Attachment manifest entry is invalid.');
      }
      final entry = AttachmentSyncEntry.fromJson(
        rawEntry.map(
          (key, value) => MapEntry<String, dynamic>(key.toString(), value),
        ),
      );
      if (!paths.add(entry.relativePath)) {
        throw const FormatException(
          'Attachment manifest contains a duplicate path.',
        );
      }
      entries.add(entry);
    }
    final version = _readAttachmentInt(
      json['version'],
      fallback: attachmentSyncManifestVersion,
    );
    if (version != attachmentSyncManifestVersion) {
      throw const FormatException('Unsupported attachment manifest version.');
    }
    return AttachmentSyncManifest(
      version: version,
      generatedAt:
          DateTime.tryParse(json['generatedAt']?.toString() ?? '')?.toUtc(),
      entries: List<AttachmentSyncEntry>.unmodifiable(entries),
    );
  }
}

class AttachmentSyncPlan {
  const AttachmentSyncPlan({
    this.files = const <AttachmentSyncEntry>[],
    this.records = const <AttachmentSyncEntry>[],
    this.tombstones = const <AttachmentSyncEntry>[],
    this.conflictingPaths = const <String>[],
  });

  const AttachmentSyncPlan.empty()
    : files = const <AttachmentSyncEntry>[],
      records = const <AttachmentSyncEntry>[],
      tombstones = const <AttachmentSyncEntry>[],
      conflictingPaths = const <String>[];

  /// Remote entries whose binary content is not present locally.
  final List<AttachmentSyncEntry> files;

  /// Remote records whose binary content is already available under another
  /// managed path, so a later transfer can avoid sending the bytes again.
  final List<AttachmentSyncEntry> records;

  /// Remote deletion records that should be applied locally in a later stage.
  final List<AttachmentSyncEntry> tombstones;

  /// Same managed path, but different active content. No automatic overwrite is
  /// allowed until a deterministic conflict policy is introduced.
  final List<String> conflictingPaths;

  int get fileCount => files.length;
  int get recordCount => records.length;
  int get tombstoneCount => tombstones.length;
  int get conflictCount => conflictingPaths.length;
  int get actionCount => fileCount + recordCount + tombstoneCount;
  bool get hasWork => actionCount > 0 || conflictCount > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'files': files.map((entry) => entry.toJson()).toList(growable: false),
    'records': records.map((entry) => entry.toJson()).toList(growable: false),
    'tombstones':
        tombstones.map((entry) => entry.toJson()).toList(growable: false),
    'conflictingPaths': conflictingPaths,
  };

  factory AttachmentSyncPlan.fromJson(Map<String, dynamic> json) {
    return AttachmentSyncPlan(
      files: _readEntryList(json['files']),
      records: _readEntryList(json['records']),
      tombstones: _readEntryList(json['tombstones']),
      conflictingPaths: _readStringList(json['conflictingPaths']),
    );
  }
}

AttachmentSyncPlan buildAttachmentSyncPlan({
  required AttachmentSyncManifest local,
  required AttachmentSyncManifest remote,
}) {
  final localByPath = <String, AttachmentSyncEntry>{
    for (final entry in local.entries) entry.relativePath: entry,
  };
  final localActiveContent = <String>{
    for (final entry in local.entries)
      if (!entry.isDeleted) _contentKey(entry),
  };
  final files = <AttachmentSyncEntry>[];
  final records = <AttachmentSyncEntry>[];
  final tombstones = <AttachmentSyncEntry>[];
  final conflicts = <String>[];

  for (final remoteEntry in remote.entries) {
    final localEntry = localByPath[remoteEntry.relativePath];
    if (remoteEntry.isDeleted) {
      if (_remoteTombstoneIsUseful(localEntry, remoteEntry)) {
        tombstones.add(remoteEntry);
      }
      continue;
    }

    if (localEntry != null) {
      if (localEntry.isDeleted) {
        // A tombstone must never be silently undone by an older active record.
        continue;
      }
      if (localEntry.sameContentAs(remoteEntry)) {
        continue;
      }
      conflicts.add(remoteEntry.relativePath);
      continue;
    }

    if (localActiveContent.contains(_contentKey(remoteEntry))) {
      records.add(remoteEntry);
    } else {
      files.add(remoteEntry);
    }
  }

  files.sort((left, right) => left.relativePath.compareTo(right.relativePath));
  records.sort(
    (left, right) => left.relativePath.compareTo(right.relativePath),
  );
  tombstones.sort(
    (left, right) => left.relativePath.compareTo(right.relativePath),
  );
  conflicts.sort();
  return AttachmentSyncPlan(
    files: List<AttachmentSyncEntry>.unmodifiable(files),
    records: List<AttachmentSyncEntry>.unmodifiable(records),
    tombstones: List<AttachmentSyncEntry>.unmodifiable(tombstones),
    conflictingPaths: List<String>.unmodifiable(conflicts),
  );
}

String _contentKey(AttachmentSyncEntry entry) =>
    '${entry.sha256}:${entry.byteLength}';

bool _remoteTombstoneIsUseful(
  AttachmentSyncEntry? local,
  AttachmentSyncEntry remote,
) {
  if (local == null) {
    return true;
  }
  if (!local.isDeleted) {
    return true;
  }
  final localDeletedAt = local.deletedAt;
  final remoteDeletedAt = remote.deletedAt;
  if (localDeletedAt == null || remoteDeletedAt == null) {
    return false;
  }
  return remoteDeletedAt.isAfter(localDeletedAt);
}

List<AttachmentSyncEntry> _readEntryList(Object? raw) {
  if (raw is! List) {
    return const <AttachmentSyncEntry>[];
  }
  if (raw.length > maxAttachmentSyncManifestEntries) {
    throw const FormatException('Attachment sync plan is too large.');
  }
  return List<AttachmentSyncEntry>.unmodifiable(
    raw.map((item) {
      if (item is! Map) {
        throw const FormatException('Attachment sync plan entry is invalid.');
      }
      return AttachmentSyncEntry.fromJson(
        item.map(
          (key, value) => MapEntry<String, dynamic>(key.toString(), value),
        ),
      );
    }),
  );
}

List<String> _readStringList(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  if (raw.length > maxAttachmentSyncManifestEntries) {
    throw const FormatException('Attachment conflict list is too large.');
  }
  return List<String>.unmodifiable(raw.map((item) => item.toString()));
}

int _readAttachmentInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _validSha256(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

bool _validAttachmentPath(String value) {
  if (!value.startsWith('Attachments/') ||
      value.length <= 'Attachments/'.length) {
    return false;
  }
  if (value.contains('\\') || value.contains('\u0000')) {
    return false;
  }
  final segments = value.split('/');
  return segments.every(
    (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
  );
}
