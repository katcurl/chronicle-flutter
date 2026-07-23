import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup JSON preserves core entities', () {
    final project = Project(
      id: 'project-1',
      title: 'Проект',
      emoji: '🧬',
      researchGoal: 'Проверить гипотезу',
      researchQuestions: const <String>['Какой результат воспроизводится?'],
      knownFindings: const <String>['Есть два состояния'],
      openChecks: const <String>['Проверить третью траекторию'],
      pinnedNoteIds: const <String>['note-1'],
      linkedSourceIds: const <String>['source-1'],
    );
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
    expect(restored.projects.single.researchGoal, 'Проверить гипотезу');
    expect(restored.projects.single.researchQuestions, <String>[
      'Какой результат воспроизводится?',
    ]);
    expect(restored.projects.single.knownFindings, <String>[
      'Есть два состояния',
    ]);
    expect(restored.projects.single.openChecks, <String>[
      'Проверить третью траекторию',
    ]);
    expect(restored.projects.single.pinnedNoteIds, <String>['note-1']);
    expect(restored.projects.single.linkedSourceIds, <String>['source-1']);
    expect(restored.tasks.single.noteId, 'note-1');
    expect(restored.notes.single.tags, ['test']);
    expect(restored.entries.single.durationSeconds, 1200);
    expect(restored.citationSources.single.citationKey, 'Jaffe2005');
    expect(restored.citationSources.single.normalizedDoi, '10.1000/example');
  });

  test('legacy backup without version remains readable', () {
    const raw = '''{
      "projects": [],
      "tasks": [],
      "notes": [],
      "entries": []
    }''';

    expect(
      AppData.formatVersionOf(raw),
      AppData.minimumReadableBackupFormatVersion,
    );
    expect(AppData.decode(raw).notes, isEmpty);
  });

  test('future backup format is refused instead of being overwritten', () {
    final raw = '''{
      "format": "${AppData.backupFormat}",
      "version": ${AppData.currentBackupFormatVersion + 1},
      "projects": [],
      "tasks": [],
      "notes": [],
      "entries": []
    }''';

    expect(() => AppData.decode(raw), throwsUnsupportedError);
  });

  test('backup requiring a newer reader is refused', () {
    final raw = '''{
      "format": "${AppData.backupFormat}",
      "version": ${AppData.currentBackupFormatVersion},
      "minimumReaderVersion": ${AppData.currentBackupFormatVersion + 1},
      "projects": [],
      "tasks": [],
      "notes": [],
      "entries": []
    }''';

    expect(() => AppData.decode(raw), throwsUnsupportedError);
  });

}
