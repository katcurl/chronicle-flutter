class VaultStatus {
  const VaultStatus({
    required this.supported,
    required this.rootPath,
    required this.noteCount,
    required this.fileCount,
    this.lastWrittenAt,
    this.message,
  });

  const VaultStatus.unavailable({this.message})
    : supported = false,
      rootPath = '',
      noteCount = 0,
      fileCount = 0,
      lastWrittenAt = null;

  final bool supported;
  final String rootPath;
  final int noteCount;
  final int fileCount;
  final DateTime? lastWrittenAt;
  final String? message;
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
}

class BackupImportPayload {
  const BackupImportPayload({
    required this.databaseJson,
    required this.preview,
    required this.sourceName,
  });

  final String databaseJson;
  final BackupPreview preview;
  final String sourceName;
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
