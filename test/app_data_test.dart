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
    final source = CitationSource(
      id: 'source-1',
      citationKey: 'Jaffe2005',
      title: 'Multistate proteins',
      authors: const ['Jaffe, Eileen'],
      year: 2005,
      doi: '10.1000/example',
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
        citationSources: [source],
      ).encode(),
    );

    expect(restored.projects.single.title, 'Проект');
    expect(restored.tasks.single.noteId, 'note-1');
    expect(restored.notes.single.tags, ['test']);
    expect(restored.entries.single.durationSeconds, 1200);
    expect(restored.citationSources.single.citationKey, 'Jaffe2005');
    expect(restored.citationSources.single.normalizedDoi, '10.1000/example');
  });
}
