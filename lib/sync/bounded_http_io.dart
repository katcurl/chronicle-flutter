import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const lanHandshakeMaxBytes = 64 * 1024;
const lanJournalEnvelopeMaxBytes = 16 * 1024 * 1024;
const lanAttachmentMetadataMaxBytes = 1024 * 1024;
const lanAttachmentBinaryMaxBytes = 100 * 1024 * 1024;
const lanAttachmentEnvelopeMaxBytes =
    ((lanAttachmentBinaryMaxBytes + 2) ~/ 3) * 4 +
    lanAttachmentMetadataMaxBytes;
const lanHttpIdleTimeout = Duration(seconds: 5);
const lanHttpCompleteTimeout = Duration(seconds: 30);
const lanMaxUnauthenticatedRequests = 16;
const lanMaxAuthenticatedSessions = 4;

class BoundedHttpException implements Exception {
  const BoundedHttpException(this.code);

  final String code;

  @override
  String toString() => 'BoundedHttpException($code)';
}

class HttpConcurrencyGate {
  HttpConcurrencyGate({required this.maxConcurrent})
    : assert(maxConcurrent > 0);

  final int maxConcurrent;
  int _active = 0;

  int get active => _active;

  bool tryAcquire() {
    if (_active >= maxConcurrent) {
      return false;
    }
    _active += 1;
    return true;
  }

  void release() {
    if (_active <= 0) {
      throw StateError('HTTP concurrency gate released without acquisition.');
    }
    _active -= 1;
  }
}

Future<Uint8List> readBoundedBytes(
  Stream<List<int>> body, {
  required int declaredContentLength,
  required int maxBytes,
  required Duration idleTimeout,
  required Duration completeTimeout,
}) {
  if (declaredContentLength < 0) {
    return Future<Uint8List>.error(
      const BoundedHttpException('content_length_required'),
    );
  }
  if (declaredContentLength > maxBytes) {
    return Future<Uint8List>.error(
      const BoundedHttpException('body_too_large'),
    );
  }
  if (maxBytes <= 0 ||
      idleTimeout <= Duration.zero ||
      completeTimeout <= Duration.zero) {
    return Future<Uint8List>.error(
      ArgumentError('HTTP limits must be positive.'),
    );
  }

  final completer = Completer<Uint8List>();
  final bytes = BytesBuilder(copy: false);
  StreamSubscription<List<int>>? subscription;
  Timer? idleTimer;
  Timer? completeTimer;
  var received = 0;

  Future<void> fail(Object error, [StackTrace? stackTrace]) async {
    if (completer.isCompleted) {
      return;
    }
    idleTimer?.cancel();
    completeTimer?.cancel();
    completer.completeError(error, stackTrace);
    await subscription?.cancel();
  }

  void resetIdleTimer() {
    idleTimer?.cancel();
    idleTimer = Timer(
      idleTimeout,
      () => unawaited(fail(const BoundedHttpException('idle_timeout'))),
    );
  }

  subscription = body.listen(
    (chunk) {
      if (completer.isCompleted) {
        return;
      }
      received += chunk.length;
      if (received > maxBytes || received > declaredContentLength) {
        unawaited(fail(const BoundedHttpException('body_too_large')));
        return;
      }
      bytes.add(chunk);
      resetIdleTimer();
    },
    onError: (Object error, StackTrace stackTrace) {
      unawaited(fail(error, stackTrace));
    },
    onDone: () {
      if (completer.isCompleted) {
        return;
      }
      idleTimer?.cancel();
      completeTimer?.cancel();
      if (received != declaredContentLength) {
        completer.completeError(
          const BoundedHttpException('content_length_mismatch'),
        );
        return;
      }
      completer.complete(bytes.takeBytes());
    },
    cancelOnError: true,
  );
  if (!completer.isCompleted) {
    resetIdleTimer();
    completeTimer = Timer(
      completeTimeout,
      () => unawaited(fail(const BoundedHttpException('complete_timeout'))),
    );
  }
  return completer.future;
}

Future<Map<String, dynamic>> readBoundedJson(
  HttpRequest request, {
  required int maxBytes,
  Duration idleTimeout = lanHttpIdleTimeout,
  Duration completeTimeout = lanHttpCompleteTimeout,
}) {
  return _readBoundedJsonStream(
    request,
    declaredContentLength: request.contentLength,
    maxBytes: maxBytes,
    idleTimeout: idleTimeout,
    completeTimeout: completeTimeout,
  );
}

Future<Map<String, dynamic>> readBoundedJsonResponse(
  HttpClientResponse response, {
  required int maxBytes,
  Duration idleTimeout = lanHttpIdleTimeout,
  Duration completeTimeout = lanHttpCompleteTimeout,
}) {
  return _readBoundedJsonStream(
    response,
    declaredContentLength: response.contentLength,
    maxBytes: maxBytes,
    idleTimeout: idleTimeout,
    completeTimeout: completeTimeout,
  );
}

Future<Map<String, dynamic>> _readBoundedJsonStream(
  Stream<List<int>> stream, {
  required int declaredContentLength,
  required int maxBytes,
  required Duration idleTimeout,
  required Duration completeTimeout,
}) async {
  final bytes = await readBoundedBytes(
    stream,
    declaredContentLength: declaredContentLength,
    maxBytes: maxBytes,
    idleTimeout: idleTimeout,
    completeTimeout: completeTimeout,
  );
  if (bytes.isEmpty) {
    return <String, dynamic>{};
  }
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

Uint8List encodeJsonBytes(Map<String, dynamic> body) {
  return Uint8List.fromList(utf8.encode(jsonEncode(body)));
}

void addJsonBody(HttpClientRequest request, Map<String, dynamic> body) {
  final bytes = encodeJsonBytes(body);
  request.headers.contentType = ContentType.json;
  request.contentLength = bytes.length;
  request.add(bytes);
}

Future<void> writeJsonResponse(
  HttpResponse response,
  int statusCode,
  Map<String, dynamic> body,
) async {
  final bytes = encodeJsonBytes(body);
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.contentLength = bytes.length;
  response.add(bytes);
  await response.close();
}
