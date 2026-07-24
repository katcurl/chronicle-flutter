import 'dart:async';

import 'package:chronicle/sync/bounded_http_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bounded HTTP input', () {
    test('rejects a missing Content-Length', () async {
      await expectLater(
        readBoundedBytes(
          Stream<List<int>>.value(<int>[1]),
          declaredContentLength: -1,
          maxBytes: 4,
          idleTimeout: const Duration(seconds: 1),
          completeTimeout: const Duration(seconds: 1),
        ),
        throwsA(
          isA<BoundedHttpException>().having(
            (error) => error.code,
            'code',
            'content_length_required',
          ),
        ),
      );
    });

    test('rejects an oversized declaration before reading', () async {
      var listened = false;
      final stream = Stream<List<int>>.multi((controller) {
        listened = true;
        controller.add(<int>[1]);
        controller.close();
      });

      await expectLater(
        readBoundedBytes(
          stream,
          declaredContentLength: 5,
          maxBytes: 4,
          idleTimeout: const Duration(seconds: 1),
          completeTimeout: const Duration(seconds: 1),
        ),
        throwsA(isA<BoundedHttpException>()),
      );
      expect(listened, isFalse);
    });

    test('stops a chunked body as soon as it crosses the cap', () async {
      await expectLater(
        readBoundedBytes(
          Stream<List<int>>.fromIterable(<List<int>>[
            <int>[1, 2],
            <int>[3, 4],
            <int>[5],
          ]),
          declaredContentLength: 4,
          maxBytes: 4,
          idleTimeout: const Duration(seconds: 1),
          completeTimeout: const Duration(seconds: 1),
        ),
        throwsA(
          isA<BoundedHttpException>().having(
            (error) => error.code,
            'code',
            'body_too_large',
          ),
        ),
      );
    });

    test('terminates a body that stalls between bytes', () async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);
      unawaited(() async {
        controller.add(<int>[1]);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (!controller.isClosed) {
          controller.add(<int>[2]);
        }
      }());

      await expectLater(
        readBoundedBytes(
          controller.stream,
          declaredContentLength: 2,
          maxBytes: 4,
          idleTimeout: const Duration(milliseconds: 20),
          completeTimeout: const Duration(seconds: 1),
        ),
        throwsA(
          isA<BoundedHttpException>().having(
            (error) => error.code,
            'code',
            'idle_timeout',
          ),
        ),
      );
    });

    test('terminates a body that exceeds the complete deadline', () async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);
      final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
        if (!controller.isClosed) {
          controller.add(<int>[1]);
        }
      });
      addTearDown(timer.cancel);

      await expectLater(
        readBoundedBytes(
          controller.stream,
          declaredContentLength: 100,
          maxBytes: 100,
          idleTimeout: const Duration(milliseconds: 25),
          completeTimeout: const Duration(milliseconds: 45),
        ),
        throwsA(
          isA<BoundedHttpException>().having(
            (error) => error.code,
            'code',
            'complete_timeout',
          ),
        ),
      );
    });
  });

  test('unauthenticated concurrency is capped at sixteen requests', () {
    final gate = HttpConcurrencyGate(maxConcurrent: 16);

    for (var index = 0; index < 16; index++) {
      expect(gate.tryAcquire(), isTrue);
    }
    for (var index = 16; index < 101; index++) {
      expect(gate.tryAcquire(), isFalse);
    }
    expect(gate.active, 16);

    gate.release();
    expect(gate.tryAcquire(), isTrue);
  });

  test('authenticated auto-sync sessions are capped at four', () {
    final gate = HttpConcurrencyGate(maxConcurrent: 4);

    for (var index = 0; index < 4; index++) {
      expect(gate.tryAcquire(), isTrue);
    }
    for (var index = 4; index < 101; index++) {
      expect(gate.tryAcquire(), isFalse);
    }
    expect(gate.active, 4);
  });
}
