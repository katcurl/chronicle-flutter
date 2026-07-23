import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/reliability/release_readiness.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('integrity audit accepts a connected workspace', () {
    final data = _healthyData();

    final report = ChronicleIntegrityAuditor.audit(data);

    expect(report.healthy, isTrue);
    expect(report.clean, isTrue);
    expect(report.errorCount, 0);
    expect(report.warningCount, 0);
    expect(report.noteCount, 1);
  });

  test('integrity audit reports orphaned entities and broken links', () {
    final data = _healthyData();
    data.notes.single.projectId = 'missing-project';
    data.tasks.single.parentTaskId = data.tasks.single.id;
    data.noteLinks.add(
      NoteLink(
        id: 'broken-link',
        sourceNoteId: 'missing-note',
        targetTitle: 'Unknown',
      ),
    );

    final report = ChronicleIntegrityAuditor.audit(data);

    expect(report.healthy, isFalse);
    expect(
      report.issues.map((issue) => issue.code),
      containsAll(<String>[
        'orphan-notes',
        'task-missing-parent',
        'note-link-broken-reference',
      ]),
    );
  });

  test('backup round-trip preserves every entity', () {
    final report = ChronicleIntegrityAuditor.verifyBackupRoundTrip(
      _healthyData().encode(),
    );

    expect(report.valid, isTrue);
    expect(report.formatVersion, AppData.currentBackupFormatVersion);
    expect(report.projectCount, 1);
    expect(report.noteCount, 1);
  });

  test('missing project research links are reported without mutation', () {
    final data = _healthyData();
    data.projects.single.pinnedNoteIds = <String>['missing-note'];
    data.projects.single.linkedSourceIds = <String>['missing-source'];

    final report = ChronicleIntegrityAuditor.audit(data);

    expect(report.clean, isFalse);
    expect(
      report.issues.map((issue) => issue.code),
      containsAll(<String>[
        'project-missing-pinned-note',
        'project-missing-linked-source',
      ]),
    );
    expect(data.projects.single.pinnedNoteIds, <String>['missing-note']);
  });

  test('readiness requires a clean audit and a valid safety backup', () {
    final integrity = ChronicleIntegrityAuditor.audit(_healthyData());
    final roundTrip = ChronicleIntegrityAuditor.verifyBackupRoundTrip(
      _healthyData().encode(),
    );
    ReleaseReadinessReport build({
      required int backups,
      int pendingChanges = 0,
    }) =>
        ReleaseReadinessReport(
          checkedAt: DateTime.utc(2026, 7, 23),
          integrity: integrity,
          backupRoundTrip: roundTrip,
          vaultStatus: VaultStatus(
            supported: true,
            rootPath: '',
            noteCount: 0,
            fileCount: 0,
            formatVersion: 2,
            pendingChangeCount: pendingChanges,
          ),
          undoDepth: 0,
          automaticBackupCount: backups,
          pendingConflictCount: 0,
        );

    expect(build(backups: 0).ready, isFalse);
    expect(build(backups: 1).ready, isTrue);
    expect(build(backups: 1, pendingChanges: 1).ready, isFalse);
  });
}

AppData _healthyData() {
  final project = Project(id: 'project-1', title: 'Research', emoji: '🧬');
  final note = Note(
    id: 'note-1',
    title: 'Result',
    projectId: project.id,
    body: '# Result\n\nStable.',
  );
  final task = WorkTask(
    id: 'task-1',
    title: 'Verify',
    projectId: project.id,
    noteId: note.id,
  );
  return AppData(
    projects: <Project>[project],
    tasks: <WorkTask>[task],
    notes: <Note>[note],
    entries: <TimeEntry>[
      TimeEntry(
        id: 'entry-1',
        description: 'Analysis',
        projectId: project.id,
        taskId: task.id,
        noteId: note.id,
        startedAt: DateTime.utc(2026, 7, 23),
        durationSeconds: 600,
      ),
    ],
    noteLinks: <NoteLink>[],
    noteVersions: <NoteVersion>[],
    citationSources: <CitationSource>[],
  );
}
