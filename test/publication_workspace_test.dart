import 'package:chronicle/features/notes/note_document.dart';
import 'package:chronicle/features/publications/publication_workspace.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var idCounter = 0;
  String nextId() => 'id-${idCounter++}';

  Note sourceNote({
    required String id,
    required String title,
    required String content,
  }) {
    final note = Note(
      id: id,
      title: title,
      projectId: 'project-1',
      body: '',
      noteType: 'analysis',
    );
    note.body = NoteDocument.serialize(note, content);
    return note;
  }

  setUp(() => idCounter = 0);

  test('publication templates provide distinct useful structures', () {
    for (final kind in PublicationKind.values) {
      final workspace = PublicationWorkspaceTemplates.create(
        kind,
        idFactory: nextId,
      );
      expect(workspace.kind, kind);
      expect(workspace.sections.length, greaterThanOrEqualTo(4));
      expect(
        workspace.sections.every((section) => section.title.trim().isNotEmpty),
        isTrue,
      );
    }
  });

  test('workspace round-trips through ordinary note properties', () {
    final source = sourceNote(
      id: 'source-1',
      title: 'RMSD analysis',
      content: '# RMSD analysis\n\n## Results\n\nTransition at frame 1200.',
    );
    final publication = Note(
      id: 'publication-1',
      title: 'Practice report',
      projectId: 'project-1',
      body: '',
    );
    final workspace = PublicationWorkspace(
      kind: PublicationKind.report,
      sections: <PublicationSection>[
        PublicationSection(
          id: 'section-1',
          title: 'Results',
          text: 'The trajectory contains two regimes.',
          fragments: <PublicationFragment>[
            PublicationFragment(
              id: 'fragment-1',
              noteId: source.id,
              heading: 'Results',
            ),
          ],
        ),
      ],
    );

    PublicationWorkspaceCodec.write(
      publication,
      workspace,
      <Note>[source],
    );
    final restored = PublicationWorkspaceCodec.read(
      Note.fromDb(publication.toDb()),
      idFactory: nextId,
    );

    expect(PublicationWorkspaceCodec.isPublication(publication), isTrue);
    expect(restored.kind, PublicationKind.report);
    expect(restored.sections.single.title, 'Results');
    expect(restored.sections.single.fragments.single.noteId, source.id);
    expect(publication.body, contains('[[id:source-1|RMSD analysis]]'));
    expect(publication.body, isNot(contains('Transition at frame 1200.')));
  });

  test('assembly resolves a live heading and builds document apparatus', () {
    final source = sourceNote(
      id: 'source-1',
      title: 'ORF9b results',
      content: '''# ORF9b results

## Methods

Molecular dynamics (MD) was run for 500 ns.

## Results

The metastable transition is visible [@smith2024].

![RMSD plot](Attachments/rmsd.png "chronicle-image width=75 align=center caption=RMSD trajectory")

| State | Frames |
| --- | ---: |
| A | 1200 |

## Discussion

This paragraph must not be included.
''',
    );
    final sourceRecord = CitationSource(
      id: 'source-record',
      citationKey: 'smith2024',
      title: 'Metastable proteins',
      authors: const <String>['Smith, A.'],
      year: 2024,
    );
    final workspace = PublicationWorkspace(
      kind: PublicationKind.article,
      sections: <PublicationSection>[
        PublicationSection(
          id: 'section-1',
          title: 'Results',
          fragments: <PublicationFragment>[
            PublicationFragment(
              id: 'fragment-1',
              noteId: source.id,
              heading: 'Results',
            ),
          ],
        ),
      ],
    );

    final assembly = assemblePublication(
      title: 'ORF9b manuscript',
      workspace: workspace,
      notes: <Note>[source],
      sources: <CitationSource>[sourceRecord],
    );

    expect(assembly.issues, isEmpty);
    expect(assembly.markdown, contains('The metastable transition is visible'));
    expect(assembly.markdown, isNot(contains('This paragraph must not be included')));
    expect(
      assembly.markdown,
      contains(
        'caption=%D0%A0%D0%B8%D1%81%D1%83%D0%BD%D0%BE%D0%BA%201.%20RMSD%20trajectory',
      ),
    );
    expect(assembly.markdown, contains('**Таблица 1.**'));
    expect(assembly.markdown, contains('## Список сокращений'));
    expect(assembly.markdown, contains('**MD**'));
    expect(assembly.markdown, contains('## Литература'));
    expect(assembly.markdown, contains('Smith, 2024'));
    expect(assembly.figureCount, 1);
    expect(assembly.tableCount, 1);
  });

  test('missing live heading is reported instead of silently copied', () {
    final source = sourceNote(
      id: 'source-1',
      title: 'Changed note',
      content: '## New heading\n\nUpdated text.',
    );
    final workspace = PublicationWorkspace(
      kind: PublicationKind.report,
      sections: <PublicationSection>[
        PublicationSection(
          id: 'section-1',
          title: 'Results',
          fragments: <PublicationFragment>[
            PublicationFragment(
              id: 'fragment-1',
              noteId: source.id,
              heading: 'Old heading',
            ),
          ],
        ),
      ],
    );

    final assembly = assemblePublication(
      title: 'Report',
      workspace: workspace,
      notes: <Note>[source],
      sources: const <CitationSource>[],
    );

    expect(assembly.issues, hasLength(1));
    expect(assembly.issues.single.fragmentId, 'fragment-1');
    expect(assembly.markdown, isNot(contains('Updated text.')));
  });
}
