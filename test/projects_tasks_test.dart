import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project and task metadata survive repository reload', () async {
    final repository = InMemoryAppRepository();
    final store = AppStore(repository: repository);
    await store.load();

    final project = Project(
      id: 'project-v10',
      title: 'Research',
      emoji: '🧬',
      colorValue: 0xFF006A6A,
      dueAt: DateTime(2026, 12, 1),
      budgetMinutes: 600,
      researchGoal: 'Identify robust metastable states',
      researchQuestions: const <String>['Which states are reproducible?'],
      knownFindings: const <String>['RMSD contains a stable transition'],
      openChecks: const <String>['Compare an independent trajectory'],
      pinnedNoteIds: const <String>['note-result'],
      linkedSourceIds: const <String>['source-jaffe'],
    );
    await store.addProject(project);

    final task = WorkTask(
      id: 'task-v10',
      title: 'Analyze trajectory',
      projectId: project.id,
      description: 'Compare the two metastable regions',
      priority: 3,
      estimateMinutes: 120,
    );
    await store.addTask(task);
    final reloaded = await repository.load();

    expect(
      reloaded.projects
          .singleWhere((item) => item.id == project.id)
          .budgetMinutes,
      600,
    );
    expect(
      reloaded.tasks.singleWhere((item) => item.id == task.id).priority,
      3,
    );
    expect(
      reloaded.tasks.singleWhere((item) => item.id == task.id).description,
      'Compare the two metastable regions',
    );

    final restoredProject = reloaded.projects.singleWhere(
      (item) => item.id == project.id,
    );
    expect(restoredProject.researchGoal, 'Identify robust metastable states');
    expect(restoredProject.researchQuestions, <String>[
      'Which states are reproducible?',
    ]);
    expect(restoredProject.knownFindings, <String>[
      'RMSD contains a stable transition',
    ]);
    expect(restoredProject.openChecks, <String>[
      'Compare an independent trajectory',
    ]);
    expect(restoredProject.pinnedNoteIds, <String>['note-result']);
    expect(restoredProject.linkedSourceIds, <String>['source-jaffe']);

    store.dispose();
  });
}
