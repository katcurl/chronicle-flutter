import 'package:chronicle/features/projects/project_research.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project research fields round-trip through existing project row', () {
    final original = Project(
      id: 'project-research',
      title: 'ORF9b',
      emoji: '🧬',
      description: 'Metastable state study',
      researchGoal: 'Compare state ensembles',
      researchQuestions: const <String>['How many stable states are present?'],
      knownFindings: const <String>['The trajectory contains a transition'],
      openChecks: const <String>['Repeat clustering with another metric'],
      pinnedNoteIds: const <String>['note-result'],
      linkedSourceIds: const <String>['source-review'],
      createdAt: DateTime.utc(2026, 7, 23),
      updatedAt: DateTime.utc(2026, 7, 23, 1),
    );

    final restored = Project.fromDb(original.toDb());

    expect(restored.description, 'Metastable state study');
    expect(restored.researchGoal, 'Compare state ensembles');
    expect(restored.researchQuestions, <String>[
      'How many stable states are present?',
    ]);
    expect(restored.knownFindings, <String>[
      'The trajectory contains a transition',
    ]);
    expect(restored.openChecks, <String>[
      'Repeat clustering with another metric',
    ]);
    expect(restored.pinnedNoteIds, <String>['note-result']);
    expect(restored.linkedSourceIds, <String>['source-review']);
  });

  test('plain legacy descriptions remain plain', () {
    final restored = Project.fromDb(<String, Object?>{
      'id': 'legacy-project',
      'title': 'Legacy',
      'emoji': '📁',
      'description': 'Ordinary old description',
      'color_value': 0xFF6750A4,
      'due_at': null,
      'budget_minutes': null,
      'archived': 0,
      'created_at': DateTime.utc(2026).toIso8601String(),
      'updated_at': DateTime.utc(2026).toIso8601String(),
    });

    expect(restored.description, 'Ordinary old description');
    expect(restored.hasResearchProfile, isFalse);
  });

  test('project material parser finds unique managed attachments', () {
    final notes = <Note>[
      Note(
        id: 'note-a',
        title: 'A',
        projectId: 'project',
        body: '![plot](Attachments/result%20plot.png)\n[file](../Attachments/data.csv)',
      ),
      Note(
        id: 'note-b',
        title: 'B',
        projectId: 'project',
        body: '[same](Attachments/result%20plot.png)\n[web](https://example.com)',
      ),
    ];

    expect(projectAttachmentPaths(notes), <String>[
      'Attachments/data.csv',
      'Attachments/result plot.png',
    ]);
  });

  test('research templates remain flexible and non-empty', () {
    expect(projectResearchTemplates.length, greaterThanOrEqualTo(4));
    for (final template in projectResearchTemplates) {
      expect(template.title.trim(), isNotEmpty);
      expect(template.researchGoal.trim(), isNotEmpty);
      expect(template.researchQuestions, isNotEmpty);
    }
  });
}
