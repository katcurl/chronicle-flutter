import '../repositories/app_repository.dart';

class BackupService {
  BackupService(this._repository);

  final AppRepository _repository;

  Future<String> exportJson() => _repository.exportJson();

  Future<void> importJson(String raw) => _repository.importJson(raw);
}
