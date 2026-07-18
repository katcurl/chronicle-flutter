import 'package:chronicle/sync/lan_sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LAN sync progress prefers byte progress for attachment transfers', () {
    const progress = LanSyncProgress(
      stage: LanSyncProgressStage.downloadingAttachment,
      completedItems: 1,
      totalItems: 4,
      bytesTransferred: 300,
      totalBytes: 1200,
      currentFileName: 'structure.png',
    );

    expect(progress.fraction, 0.25);
    expect(progress.currentFileName, 'structure.png');
  });

  test('LAN sync progress falls back to item progress', () {
    const progress = LanSyncProgress(
      stage: LanSyncProgressStage.applyingAttachmentMetadata,
      completedItems: 3,
      totalItems: 4,
    );

    expect(progress.fraction, 0.75);
  });

  test('LAN sync progress exposes selective retry attempt', () {
    const progress = LanSyncProgress(
      stage: LanSyncProgressStage.retryingAttachment,
      completedItems: 2,
      totalItems: 5,
      currentFileName: 'trajectory.zip',
      retryAttempt: 2,
    );

    expect(progress.fraction, 0.4);
    expect(progress.retryAttempt, 2);
    expect(progress.currentFileName, 'trajectory.zip');
  });

  test('LAN sync progress is indeterminate without known totals', () {
    const progress = LanSyncProgress(
      stage: LanSyncProgressStage.preparing,
    );

    expect(progress.fraction, isNull);
  });
}
