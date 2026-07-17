import 'package:chronicle/reliability/reliability_models.dart';
import 'package:chronicle/reliability/reliability_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('diagnostic events persist, round-trip and respect retention', () async {
    final service = ReliabilityService();
    await service.load();

    for (var index = 0; index < ReliabilityService.maxEventCount + 7; index++) {
      await service.record(
        stage: ReliabilityStage.transfer,
        level: index.isEven ? ReliabilityLevel.success : ReliabilityLevel.info,
        message: 'Событие $index',
        peerDeviceId: 'peer-1',
        details: <String, Object?>{'sent': index},
      );
    }

    expect(service.events, hasLength(ReliabilityService.maxEventCount));
    expect(service.events.first.message, 'Событие 126');
    expect(service.events.last.message, 'Событие 7');

    final restored = ReliabilityService();
    await restored.load();

    expect(restored.events, hasLength(ReliabilityService.maxEventCount));
    expect(restored.events.first.stage, ReliabilityStage.transfer);
    expect(restored.events.first.details['sent'], 126);
  });

  test('automatic backup becomes due after the configured interval', () async {
    final service = ReliabilityService();
    await service.load();

    final now = DateTime.utc(2026, 7, 17, 12);
    expect(service.automaticBackupDue(now: now), isTrue);

    await service.markAutomaticBackup(
      createdAt: now,
      path: '/tmp/automatic-backup.chronicle',
    );

    expect(
      service.automaticBackupDue(now: now.add(const Duration(hours: 23))),
      isFalse,
    );
    expect(
      service.automaticBackupDue(now: now.add(const Duration(hours: 24))),
      isTrue,
    );

    final restored = ReliabilityService();
    await restored.load();
    expect(restored.lastAutomaticBackupAt, now);
    expect(restored.lastAutomaticBackupPath, '/tmp/automatic-backup.chronicle');
  });

  test('event parser falls back safely for unknown enum values', () {
    final event = ReliabilityEvent.fromJson(<String, Object?>{
      'id': 'event-1',
      'occurredAt': '2026-07-17T12:00:00Z',
      'stage': 'future-stage',
      'level': 'future-level',
      'message': 'Тест',
      'details': <String, Object?>{'ok': true},
    });

    expect(event.stage, ReliabilityStage.system);
    expect(event.level, ReliabilityLevel.info);
    expect(event.details['ok'], isTrue);
  });
}
