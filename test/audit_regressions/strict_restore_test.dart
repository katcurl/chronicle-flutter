import 'package:chronicle/data/database/chronicle_database.dart';
import 'package:chronicle/data/repositories/drift_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/restore_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty JSON object is rejected and preserves populated data', () async {
    final database = ChronicleDatabase(NativeDatabase.memory());
    final repository = DriftAppRepository(database: database);
    addTearDown(repository.close);

    await repository.replaceAll(
      AppData(
        projects: [Project(id: 'p', title: 'Important', emoji: '📌')],
        tasks: const [],
        notes: [
          Note(
            id: 'n',
            title: 'Irreplaceable',
            projectId: 'p',
            body: 'valuable data',
          ),
        ],
        entries: const [],
      ),
    );

    final result = await RestoreService(repository).restore('{}');
    expect(result.valid, isFalse);

    final restored = await repository.load();
    expect(restored.projects.single.id, 'p');
    expect(restored.notes.single.id, 'n');
    expect(restored.notes.single.body, 'valuable data');
  });

  test('partial legacy object is not treated as an empty backup', () {
    expect(
      () => AppData.decode('{"projects":[],"tasks":[],"notes":[]}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('restore validation rejects JSON without a Chronicle schema', () async {
    final database = ChronicleDatabase(NativeDatabase.memory());
    final repository = DriftAppRepository(database: database);
    addTearDown(repository.close);

    final result = await RestoreService(repository).validate('{}');

    expect(result.valid, isFalse);
    expect(result.sha256, isNull);
  });
}
