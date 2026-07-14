import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup JSON preserves core entities', () {
    final project = Project(id: 'project-1', title: 'Проект', emoji: '🧬');
    final note = Note(
      id: 'note-1',
      title: 'Заметка',
      projectId: project.id,
      body: '# Текст',
      tags: const ['test'],
    );
    final task = WorkTask(
      id: 'task-1',
      title: 'Задача',
      projectId: project.id,
      noteId: note.id,
    );
    final entry = TimeEntry(
      id: 'entry-1',
      description: 'Работа',
      projectId: project.id,
      taskId: task.id,
      noteId: note.id,
      startedAt: DateTime.utc(2026, 7, 14, 9),
      durationSeconds: 1200,
    );

    final restored = AppData.decode(
      AppData(
        projects: [project],
        tasks: [task],
        notes: [note],
        entries: [entry],
      ).encode(),
    );

    expect(restored.projects.single.title, 'Проект');
    expect(restored.tasks.single.noteId, 'note-1');
    expect(restored.notes.single.tags, ['test']);
    expect(restored.entries.single.durationSeconds, 1200);
  });
}
