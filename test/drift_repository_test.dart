import 'package:chronicle/data/database/chronicle_database.dart';
import 'package:chronicle/data/repositories/drift_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Drift repository persists the existing Chronicle domain model',
    () async {
      final database = ChronicleDatabase(NativeDatabase.memory());
      final repository = DriftAppRepository(database: database);

      final project = Project(
        id: 'project-drift',
        title: 'Кроссплатформенный проект',
        emoji: '🖥️',
      );
      final note = Note(
        id: 'note-drift',
        title: 'Desktop',
        projectId: project.id,
        body: '# Chronicle Desktop',
      );
      final task = WorkTask(
        id: 'task-drift',
        title: 'Проверить Drift',
        projectId: project.id,
        noteId: note.id,
      );

      await repository.replaceAll(
        AppData(projects: [project], tasks: [task], notes: [note], entries: []),
      );
      await repository.markInitialized();

      final restored = await repository.load();

      expect(await repository.isInitialized(), isTrue);
      expect(restored.projects.single.title, project.title);
      expect(restored.tasks.single.noteId, note.id);
      expect(restored.notes.single.body, note.body);

      await repository.close();
    },
  );
}
