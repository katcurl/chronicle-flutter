import 'dart:io';

import 'package:chronicle/application/tasks/task_commands.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/data/repositories/mutation_queue.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed project archive does not mutate published state', () async {
    final project = Project(id: 'project', title: 'Project', emoji: 'P');
    final data = AppData(
      projects: <Project>[project],
      tasks: <WorkTask>[],
      notes: <Note>[],
      entries: <TimeEntry>[],
    );
    final commands = TaskCommands(
      repository: _FailingProjectRepository(initialData: data),
      mutationQueue: MutationQueue(),
      currentData: () => data,
      registerUndo: ({required label, required restore}) {},
      scheduleSync: () {},
      notifyListeners: () {},
    );

    await expectLater(
      commands.setProjectArchived(project, true),
      throwsA(isA<FileSystemException>()),
    );

    expect(data.projects.single.archived, isFalse);
  });
}

final class _FailingProjectRepository extends InMemoryAppRepository {
  _FailingProjectRepository({required super.initialData});

  @override
  Future<void> saveProject(Project project) {
    throw const FileSystemException('simulated persistence failure');
  }
}
