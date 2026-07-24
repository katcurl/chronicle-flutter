import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/reliability/release_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('time entries validate optional task and note references', () {
    final data = _baseData();
    data.entries.add(
      TimeEntry(
        id: 'broken-entry',
        description: 'Broken',
        projectId: 'project',
        taskId: 'missing-task',
        noteId: 'missing-note',
        startedAt: DateTime.utc(2026, 7, 24),
        durationSeconds: 10,
      ),
    );

    final report = ChronicleIntegrityAuditor.audit(data);

    expect(
      report.issues.map((issue) => issue.code),
      containsAll(<String>[
        'time-entry-missing-task',
        'time-entry-missing-note',
      ]),
    );
  });

  test('multi-node task parent cycles are reported in full', () {
    final data = _baseData();
    data.tasks.addAll([
      WorkTask(id: 'a', title: 'A', projectId: 'project', parentTaskId: 'b'),
      WorkTask(id: 'b', title: 'B', projectId: 'project', parentTaskId: 'c'),
      WorkTask(id: 'c', title: 'C', projectId: 'project', parentTaskId: 'a'),
    ]);

    final report = ChronicleIntegrityAuditor.audit(data);
    final issue = report.issues.singleWhere(
      (candidate) => candidate.code == 'task-parent-cycle',
    );

    expect(issue.entityIds, <String>['a', 'b', 'c']);
  });

  test('negative durations and duplicate decoded IDs fail integrity', () {
    final data = _baseData();
    data.entries.add(
      TimeEntry(
        id: 'negative',
        description: 'Impossible',
        projectId: 'project',
        startedAt: DateTime.utc(2026, 7, 24),
        durationSeconds: -1,
      ),
    );
    data.notes.add(
      Note(id: 'note', title: 'Duplicate', projectId: 'project', body: ''),
    );

    final report = ChronicleIntegrityAuditor.audit(data);

    expect(report.healthy, isFalse);
    expect(
      report.issues.map((issue) => issue.code),
      containsAll(<String>[
        'time-entry-negative-duration',
        'duplicate-note-id',
      ]),
    );
  });
}

AppData _baseData() {
  return AppData(
    projects: [Project(id: 'project', title: 'Project', emoji: '🧪')],
    tasks: [
      WorkTask(id: 'task', title: 'Task', projectId: 'project', noteId: 'note'),
    ],
    notes: [Note(id: 'note', title: 'Note', projectId: 'project', body: '')],
    entries: <TimeEntry>[],
  );
}
