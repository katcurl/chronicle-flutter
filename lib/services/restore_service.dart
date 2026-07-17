import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/repositories/app_repository.dart';

class RestoreValidationResult {
  const RestoreValidationResult({
    required this.valid,
    required this.message,
    this.sha256,
  });

  final bool valid;
  final String message;
  final String? sha256;
}

class RestoreService {
  RestoreService(this._repository);

  final AppRepository _repository;

  Future<RestoreValidationResult> validate(String raw) async {
    try {
      jsonDecode(raw);
      final hash = sha256.convert(utf8.encode(raw)).toString();
      return RestoreValidationResult(
        valid: true,
        message: 'Резервная копия проверена.',
        sha256: hash,
      );
    } on Object {
      return const RestoreValidationResult(
        valid: false,
        message: 'Резервная копия повреждена.',
      );
    }
  }

  Future<RestoreValidationResult> restore(String raw) async {
    final result = await validate(raw);
    if (!result.valid) {
      return result;
    }

    await _repository.importJson(raw);
    return result;
  }
}
