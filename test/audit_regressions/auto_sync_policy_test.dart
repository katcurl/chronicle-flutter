import 'package:chronicle/sync/lan_auto_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('incoming auto sync requires both global and peer permission', () async {
    var globalEnabled = false;
    var peerEnabled = true;
    final policy = IncomingAutoSyncPolicy(
      globallyEnabled: () async => globalEnabled,
      peerEnabled: (_) async => peerEnabled,
    );

    expect(await policy.allows('peer'), isFalse);
    globalEnabled = true;
    peerEnabled = false;
    expect(await policy.allows('peer'), isFalse);
    peerEnabled = true;
    expect(await policy.allows('peer'), isTrue);
  });
}
