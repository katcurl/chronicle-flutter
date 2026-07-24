abstract final class BackupLimits {
  static const int maxRawBytes = 768 * 1024 * 1024;
  static const int maxAttachmentBytes = 100 * 1024 * 1024;
  static const int maxDecodedAttachmentBytes = 512 * 1024 * 1024;
  static const int maxAttachmentCount = 10000;
}

final class BackupResourceLimits {
  const BackupResourceLimits({
    this.maxRawBytes = BackupLimits.maxRawBytes,
    this.maxAttachmentBytes = BackupLimits.maxAttachmentBytes,
    this.maxDecodedAttachmentBytes = BackupLimits.maxDecodedAttachmentBytes,
    this.maxAttachmentCount = BackupLimits.maxAttachmentCount,
  });

  final int maxRawBytes;
  final int maxAttachmentBytes;
  final int maxDecodedAttachmentBytes;
  final int maxAttachmentCount;
}

final class BackupLimitException extends FormatException {
  const BackupLimitException(super.message);
}
