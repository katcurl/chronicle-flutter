import 'dart:typed_data';

import '../models/app_models.dart';

class VaultStatus {
  const VaultStatus({
    required this.supported,
    required this.rootPath,
    required this.noteCount,
    required this.fileCount,
    this.lastWrittenAt,
    this.message,
    this.pendingChangeCount = 0,
    this.conflictCount = 0,
    this.missingFileCount = 0,
    this.attachmentCount = 0,
    this.formatVersion,
    this.minimumReaderVersion,
    this.readOnly = false,
  });

  const VaultStatus.unavailable({this.message})
    : supported = false,
      rootPath = '',
      noteCount = 0,
      fileCount = 0,
      lastWrittenAt = null,
      pendingChangeCount = 0,
      conflictCount = 0,
      missingFileCount = 0,
      attachmentCount = 0,
      formatVersion = null,
      minimumReaderVersion = null,
      readOnly = false;

  final bool supported;
  final String rootPath;
  final int noteCount;
  final int fileCount;
  final DateTime? lastWrittenAt;
  final String? message;
  final int pendingChangeCount;
  final int conflictCount;
  final int missingFileCount;
  final int attachmentCount;
  final int? formatVersion;
  final int? minimumReaderVersion;
  final bool readOnly;

  bool get writable => supported && !readOnly;

  VaultStatus copyWith({
    bool? supported,
    String? rootPath,
    int? noteCount,
    int? fileCount,
    DateTime? lastWrittenAt,
    String? message,
    bool clearMessage = false,
    int? pendingChangeCount,
    int? conflictCount,
    int? missingFileCount,
    int? attachmentCount,
    int? formatVersion,
    int? minimumReaderVersion,
    bool? readOnly,
  }) {
    return VaultStatus(
      supported: supported ?? this.supported,
      rootPath: rootPath ?? this.rootPath,
      noteCount: noteCount ?? this.noteCount,
      fileCount: fileCount ?? this.fileCount,
      lastWrittenAt: lastWrittenAt ?? this.lastWrittenAt,
      message: clearMessage ? null : message ?? this.message,
      pendingChangeCount: pendingChangeCount ?? this.pendingChangeCount,
      conflictCount: conflictCount ?? this.conflictCount,
      missingFileCount: missingFileCount ?? this.missingFileCount,
      attachmentCount: attachmentCount ?? this.attachmentCount,
      formatVersion: formatVersion ?? this.formatVersion,
      minimumReaderVersion: minimumReaderVersion ?? this.minimumReaderVersion,
      readOnly: readOnly ?? this.readOnly,
    );
  }
}

enum VaultChangeKind { newNote, externalUpdate, movedOrRenamed, conflict }

class VaultNoteChange {
  const VaultNoteChange({
    required this.kind,
    required this.relativePath,
    required this.proposedNote,
    required this.fileHash,
    this.currentNoteId,
    this.previousPath,
    this.baselineHash,
    this.databaseHash,
  });

  final VaultChangeKind kind;
  final String relativePath;
  final Note proposedNote;
  final String fileHash;
  final String? currentNoteId;
  final String? previousPath;
  final String? baselineHash;
  final String? databaseHash;

  bool get isConflict => kind == VaultChangeKind.conflict;
  bool get isNew => kind == VaultChangeKind.newNote;

  /// Stable key used by the conflict center to keep an independent decision
  /// for every conflicting Markdown file.
  String get decisionKey =>
      '${currentNoteId ?? proposedNote.id}::$relativePath';
}

class VaultMissingFile {
  const VaultMissingFile({required this.noteId, required this.relativePath});

  final String noteId;
  final String relativePath;
}

class VaultScanResult {
  const VaultScanResult({
    required this.rootPath,
    required this.scannedAt,
    required this.changes,
    required this.missingFiles,
  });

  final String rootPath;
  final DateTime scannedAt;
  final List<VaultNoteChange> changes;
  final List<VaultMissingFile> missingFiles;

  List<VaultNoteChange> get safeChanges =>
      changes.where((change) => !change.isConflict).toList(growable: false);

  List<VaultNoteChange> get conflicts =>
      changes.where((change) => change.isConflict).toList(growable: false);

  int get pendingCount => changes.length + missingFiles.length;
  bool get hasChanges => pendingCount > 0;
}

enum VaultConflictResolution { keepChronicle, importFile, keepBoth }

enum VaultMissingFileResolution { restoreFiles, deleteNotes }

class VaultApplyResult {
  const VaultApplyResult({
    required this.createdCount,
    required this.updatedCount,
    required this.duplicatedCount,
    required this.keptChronicleCount,
    required this.restoredFileCount,
    this.deletedCount = 0,
    this.safetyBackupPath,
  });

  final int createdCount;
  final int updatedCount;
  final int duplicatedCount;
  final int keptChronicleCount;
  final int restoredFileCount;
  final int deletedCount;
  final String? safetyBackupPath;

  int get appliedCount =>
      createdCount + updatedCount + duplicatedCount + deletedCount;
}

class AttachmentImportResult {
  const AttachmentImportResult({
    required this.fileName,
    required this.relativePath,
    required this.markdown,
    required this.byteLength,
    required this.isImage,
    required this.sha256,
    required this.mimeType,
    required this.alreadyExisted,
  });

  final String fileName;
  final String relativePath;
  final String markdown;
  final int byteLength;
  final bool isImage;
  final String sha256;
  final String mimeType;
  final bool alreadyExisted;
}

class VaultAttachmentRecord {
  const VaultAttachmentRecord({
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

  Map<String, dynamic> toJson() => {
    'path': relativePath,
    'originalName': originalName,
    'sha256': sha256,
    'mimeType': mimeType,
    'byteLength': byteLength,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  factory VaultAttachmentRecord.fromJson(Map<String, dynamic> json) {
    return VaultAttachmentRecord(
      relativePath: json['path']?.toString() ?? '',
      originalName: json['originalName']?.toString() ?? '',
      sha256: json['sha256']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
      byteLength: _attachmentInt(json['byteLength']),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      deletedAt: DateTime.tryParse(json['deletedAt']?.toString() ?? ''),
    );
  }

  VaultAttachmentRecord copyWith({
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return VaultAttachmentRecord(
      relativePath: relativePath,
      originalName: originalName,
      sha256: sha256,
      mimeType: mimeType,
      byteLength: byteLength,
      createdAt: createdAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    );
  }
}

class AttachmentDeleteResult {
  const AttachmentDeleteResult({
    required this.relativePath,
    required this.deletedFile,
    required this.tombstoneCreated,
  });

  final String relativePath;
  final bool deletedFile;
  final bool tombstoneCreated;
}

class BackupPreview {
  const BackupPreview({
    required this.formatVersion,
    required this.exportedAt,
    required this.projectCount,
    required this.taskCount,
    required this.noteCount,
    required this.entryCount,
    required this.checksumsVerified,
    this.sourceDeviceId,
    this.sourceDeviceName,
    this.attachmentCount = 0,
  });

  final int formatVersion;
  final DateTime exportedAt;
  final int projectCount;
  final int taskCount;
  final int noteCount;
  final int entryCount;
  final bool checksumsVerified;
  final String? sourceDeviceId;
  final String? sourceDeviceName;
  final int attachmentCount;
}

class BackupImportPayload {
  const BackupImportPayload({
    required this.databaseJson,
    required this.preview,
    required this.sourceName,
    this.attachments = const {},
    this.vaultFiles = const {},
  });

  final String databaseJson;
  final BackupPreview preview;
  final String sourceName;
  final Map<String, Uint8List> attachments;
  final Map<String, String> vaultFiles;
}

class BackupExportResult {
  const BackupExportResult({
    required this.path,
    required this.fileName,
    required this.preview,
  });

  final String path;
  final String fileName;
  final BackupPreview preview;
}

class BackupCatalogEntry {
  const BackupCatalogEntry({
    required this.path,
    required this.fileName,
    required this.modifiedAt,
    required this.byteLength,
    this.preview,
    this.validationError,
  });

  final String path;
  final String fileName;
  final DateTime modifiedAt;
  final int byteLength;
  final BackupPreview? preview;
  final String? validationError;

  bool get isValid =>
      preview != null &&
      preview!.checksumsVerified &&
      (validationError == null || validationError!.isEmpty);
}

class EmergencyBackupSnapshot {
  const EmergencyBackupSnapshot({required this.path, required this.payload});

  final String path;
  final BackupImportPayload payload;
}

int _attachmentInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
