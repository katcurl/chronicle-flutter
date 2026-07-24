import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

import '../data/database/chronicle_database.dart';
import '../data/repositories/drift_app_repository.dart';
import '../models/app_models.dart';
import '../reliability/release_readiness.dart';
import '../vault/atomic_file_writer.dart';
import 'recovery_storage_contract.dart';

typedef DatabasePathResolver = Future<String> Function();
typedef RecoveryExportDirectoryPicker = Future<String?> Function();

final class IoRecoveryStorage implements RecoveryStorage {
  IoRecoveryStorage({
    DatabasePathResolver? databasePathResolver,
    RecoveryExportDirectoryPicker? exportDirectoryPicker,
    AtomicFileWriter? atomicFileWriter,
  }) : _databasePathResolver =
           databasePathResolver ?? locateChronicleDatabasePath,
       _exportDirectoryPicker =
           exportDirectoryPicker ??
           (() => FilePicker.getDirectoryPath(
             dialogTitle: 'Экспортировать аварийную копию Chronicle',
           )),
       _atomicFileWriter = atomicFileWriter ?? createAtomicFileWriter();

  static const int _maximumArchives = 20;
  static const List<String> _criticalJsonStateKeys = <String>[
    'active_timer',
    'sync_preferences',
    'device_key_material_v1',
    'citation_sources_v1',
    'sync_journal_compaction_metadata_v1',
  ];

  final DatabasePathResolver _databasePathResolver;
  final RecoveryExportDirectoryPicker _exportDirectoryPicker;
  final AtomicFileWriter _atomicFileWriter;
  final Uuid _uuid = const Uuid();

  @override
  Future<RecoveryDatabaseProbe> inspectActiveDatabase() async {
    final databasePath = await _databasePathResolver();
    return _inspectDatabase(File(databasePath), rejectUncheckpointedWal: true);
  }

  @override
  Future<List<RecoveryDatabaseArchive>> listDatabaseArchives() async {
    final active = File(await _databasePathResolver());
    final directory = Directory(p.join(active.parent.path, 'Recovery'));
    if (!await directory.exists()) {
      return const <RecoveryDatabaseArchive>[];
    }
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.sqlite')) {
        files.add(entity);
      }
    }
    files.sort(
      (left, right) =>
          right.statSync().modified.compareTo(left.statSync().modified),
    );
    final result = <RecoveryDatabaseArchive>[];
    for (final file in files.take(_maximumArchives)) {
      final stat = await file.stat();
      final probe = await _inspectDatabase(
        file,
        rejectUncheckpointedWal: false,
      );
      result.add(
        RecoveryDatabaseArchive(
          path: file.path,
          modifiedAt: stat.modified,
          byteLength: stat.size,
          quickCheckHealthy: probe.isHealthy,
          generation: probe.generation,
        ),
      );
    }
    return result;
  }

  @override
  Future<String> exportRawDatabase({required String diagnosticsJson}) async {
    final selected = await _exportDirectoryPicker();
    if (selected == null || selected.trim().isEmpty) {
      return '';
    }
    final active = File(await _databasePathResolver());
    final stamp = _fileStamp(DateTime.now().toUtc());
    final exportDirectory = Directory(
      p.join(selected, 'chronicle-recovery-$stamp'),
    );
    await exportDirectory.create(recursive: true);

    for (final suffix in const <String>['', '-wal', '-shm', '-journal']) {
      final source = File('${active.path}$suffix');
      if (!await source.exists()) {
        continue;
      }
      final target = File(
        p.join(exportDirectory.path, '${p.basename(active.path)}$suffix'),
      );
      await source.copy(target.path);
      if (await target.length() != await source.length()) {
        throw StateError('Аварийная копия SQLite записана не полностью.');
      }
    }
    await _atomicFileWriter.replace(
      p.join(exportDirectory.path, 'chronicle-recovery.json'),
      utf8.encode(diagnosticsJson),
    );
    return exportDirectory.path;
  }

  @override
  Future<void> installDatabase(
    AppData data, {
    required String generation,
  }) async {
    if (!_safeIdentifier(generation)) {
      throw const FormatException(
        'Generation восстановления имеет неверный формат.',
      );
    }
    final integrity = ChronicleIntegrityAuditor.audit(data);
    if (!integrity.clean) {
      throw StateError(
        'Резервная копия содержит ${integrity.issues.length} '
        'ошибок связности данных.',
      );
    }

    final active = File(await _databasePathResolver());
    await active.parent.create(recursive: true);
    await _rejectUnsafeSidecars(active);
    final candidate = File(
      p.join(active.parent.path, '.chronicle-recovery-${_uuid.v4()}.sqlite'),
    );
    await _deleteSqliteFamily(candidate);

    final database = ChronicleDatabase(NativeDatabase(candidate));
    final repository = DriftAppRepository(database: database);
    try {
      await repository.replaceAllForRestore(data, generation: generation);
      final reloaded = await repository.load();
      final reloadedIntegrity = ChronicleIntegrityAuditor.audit(reloaded);
      if (!reloadedIntegrity.clean) {
        throw StateError(
          'Подготовленная база не прошла проверку связности данных.',
        );
      }
    } finally {
      await repository.close();
    }

    final candidateProbe = await _inspectDatabase(
      candidate,
      rejectUncheckpointedWal: true,
    );
    if (!candidateProbe.isHealthy ||
        candidateProbe.generation != generation ||
        candidateProbe.schemaVersion != chronicleDatabaseSchemaVersion) {
      await _deleteSqliteFamily(candidate);
      throw StateError('Подготовленная база не прошла проверку SQLite.');
    }

    try {
      if (await active.exists()) {
        final recoveryDirectory = Directory(
          p.join(active.parent.path, 'Recovery'),
        );
        await recoveryDirectory.create(recursive: true);
        final archive = File(
          p.join(
            recoveryDirectory.path,
            '${_fileStamp(DateTime.now().toUtc())}-chronicle.sqlite',
          ),
        );
        await active.copy(archive.path);
        if (await archive.length() != await active.length()) {
          throw StateError('Предыдущая SQLite сохранена не полностью.');
        }
      }
      await _atomicFileWriter.replaceFile(active.path, candidate.path);
      await _deleteHarmlessSidecars(active);
    } on Object {
      if (await candidate.exists()) {
        await _deleteSqliteFamily(candidate);
      }
      rethrow;
    }
  }

  Future<RecoveryDatabaseProbe> _inspectDatabase(
    File file, {
    required bool rejectUncheckpointedWal,
  }) async {
    if (!await file.exists()) {
      return RecoveryDatabaseProbe(
        path: file.path,
        exists: false,
        byteLength: 0,
        schemaVersion: null,
        generation: null,
        quickCheckHealthy: true,
        blockingProblems: const <RecoveryProblem>[],
      );
    }
    final problems = <RecoveryProblem>[];
    if (rejectUncheckpointedWal) {
      final wal = File('${file.path}-wal');
      if (await wal.exists() && await wal.length() > 0) {
        problems.add(
          const RecoveryProblem(
            code: 'uncheckpointed-wal',
            message:
                'Обнаружен незавершённый SQLite WAL. Сначала экспортируйте '
                'аварийную копию.',
          ),
        );
      }
    }

    sqlite.Database? database;
    int? schemaVersion;
    String? generation;
    var quickCheckHealthy = false;
    try {
      database = sqlite.sqlite3.open(
        _immutableUri(file.path),
        mode: sqlite.OpenMode.readOnly,
        uri: true,
      );
      final quickCheck = database.select('PRAGMA quick_check');
      quickCheckHealthy =
          quickCheck.length == 1 &&
          quickCheck.first.columnAt(0)?.toString() == 'ok';
      if (!quickCheckHealthy) {
        problems.add(
          const RecoveryProblem(
            code: 'sqlite-quick-check',
            message: 'SQLite quick_check обнаружил повреждение базы.',
          ),
        );
      }
      final versions = database.select('PRAGMA user_version');
      schemaVersion =
          versions.isEmpty ? null : versions.first.columnAt(0) as int?;
      if (schemaVersion == null ||
          schemaVersion < 1 ||
          schemaVersion > chronicleDatabaseSchemaVersion) {
        problems.add(
          RecoveryProblem(
            code: 'unsupported-schema',
            message: 'Версия схемы SQLite не поддерживается: $schemaVersion.',
          ),
        );
      }

      final hasState =
          database
              .select(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' "
                "AND name = 'app_state' LIMIT 1",
              )
              .isNotEmpty;
      if (!hasState) {
        problems.add(
          const RecoveryProblem(
            code: 'missing-app-state',
            message: 'В базе отсутствует системная таблица app_state.',
          ),
        );
      } else {
        final placeholders = List<String>.filled(
          _criticalJsonStateKeys.length,
          '?',
        ).join(',');
        final rows = database.select(
          'SELECT key, value FROM app_state WHERE key IN ($placeholders)',
          _criticalJsonStateKeys,
        );
        for (final row in rows) {
          final key = row['key']?.toString() ?? '';
          final value = row['value']?.toString() ?? '';
          if (!_validCriticalState(key, value)) {
            problems.add(
              RecoveryProblem(
                code: 'malformed-state-$key',
                message: 'Системная запись $key повреждена.',
              ),
            );
          }
        }
        final generationRows = database.select(
          "SELECT value FROM app_state WHERE key = 'data_generation_v1' "
          'LIMIT 1',
        );
        if (generationRows.isNotEmpty) {
          final candidate = generationRows.first['value']?.toString();
          if (candidate != null && _safeIdentifier(candidate)) {
            generation = candidate;
          } else {
            problems.add(
              const RecoveryProblem(
                code: 'malformed-generation',
                message: 'Идентификатор generation повреждён.',
              ),
            );
          }
        }
      }
    } on Object {
      problems.add(
        const RecoveryProblem(
          code: 'sqlite-open-failed',
          message: 'Базу SQLite не удалось прочитать в безопасном режиме.',
        ),
      );
    } finally {
      database?.close();
    }
    return RecoveryDatabaseProbe(
      path: file.path,
      exists: true,
      byteLength: await file.length(),
      schemaVersion: schemaVersion,
      generation: generation,
      quickCheckHealthy: quickCheckHealthy,
      blockingProblems: List<RecoveryProblem>.unmodifiable(problems),
    );
  }

  Future<void> _rejectUnsafeSidecars(File active) async {
    for (final suffix in const <String>['-wal', '-journal']) {
      final sidecar = File('${active.path}$suffix');
      if (await sidecar.exists() && await sidecar.length() > 0) {
        throw StateError(
          'SQLite содержит незавершённый $suffix. '
          'Автоматическая замена остановлена.',
        );
      }
    }
  }

  Future<void> _deleteHarmlessSidecars(File active) async {
    for (final suffix in const <String>['-wal', '-shm', '-journal']) {
      final sidecar = File('${active.path}$suffix');
      if (await sidecar.exists()) {
        if (suffix != '-shm' && await sidecar.length() > 0) {
          throw StateError('Нельзя удалить непустой SQLite sidecar $suffix.');
        }
        await sidecar.delete();
      }
    }
  }
}

bool _validCriticalState(String key, String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (key == 'citation_sources_v1') {
      return decoded is List;
    }
    return decoded is Map;
  } on Object {
    return false;
  }
}

String _immutableUri(String filePath) =>
    Uri.file(filePath)
        .replace(queryParameters: const <String, String>{'immutable': '1'})
        .toString();

bool _safeIdentifier(String value) =>
    value.isNotEmpty && RegExp(r'^[A-Za-z0-9-]{1,128}$').hasMatch(value);

String _fileStamp(DateTime value) => value
    .toIso8601String()
    .replaceAll(':', '-')
    .replaceAll('.', '-')
    .replaceAll('Z', '');

Future<void> _deleteSqliteFamily(File database) async {
  for (final suffix in const <String>['', '-wal', '-shm', '-journal']) {
    final candidate = File('${database.path}$suffix');
    if (await candidate.exists()) {
      await candidate.delete();
    }
  }
}
