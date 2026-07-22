import 'dart:convert';
import 'dart:typed_data';

import 'package:chronicle/features/notes/note_document.dart';
import 'package:chronicle/features/notes/note_export.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Note note({
    required String id,
    required String title,
    required String content,
  }) {
    final value = Note(
      id: id,
      title: title,
      projectId: 'project-1',
      body: '',
      tags: const <String>['orf9b'],
      noteType: 'experiment',
      status: 'active',
      createdAt: DateTime.utc(2026, 7, 22),
      updatedAt: DateTime.utc(2026, 7, 23),
    );
    value.body = NoteDocument.serialize(value, content);
    return value;
  }

  test('note archive includes portable documents and referenced assets', () async {
    final source = note(
      id: 'note-1',
      title: 'RMSD analysis',
      content: '''# Results

![Plot](../../Attachments/plot--abc.png "chronicle-image width=50 align=center caption=RMSD")

[Data](../../Attachments/data--def.csv)
''',
    );
    final bytesByPath = <String, Uint8List>{
      'Attachments/plot--abc.png': Uint8List.fromList(<int>[137, 80, 78, 71]),
      'Attachments/data--def.csv': Uint8List.fromList(utf8.encode('x,y\n1,2')),
    };

    final payload = await NoteExportComposer(
      readAttachment: (path) async => bytesByPath[path],
    ).exportNote(
      note: source,
      projectTitle: 'ORF9b',
      format: ChronicleExportFormat.portableArchive,
    );

    expect(payload.extension, 'zip');
    expect(payload.assetCount, 2);
    expect(payload.missingAttachments, isEmpty);

    final entries = StoredZipArchiveBuilder.readStoredEntries(payload.bytes);
    expect(
      entries.keys,
      containsAll(<String>[
        'RMSD analysis.md',
        'RMSD analysis.html',
        'manifest.json',
        'assets/plot--abc.png',
        'assets/data--def.csv',
      ]),
    );
    final markdown = utf8.decode(entries['RMSD analysis.md']!);
    expect(markdown, contains('chronicle_id: "note-1"'));
    expect(markdown, contains('assets/plot--abc.png'));
    final html = utf8.decode(entries['RMSD analysis.html']!);
    final normalizedHtml = html.replaceAll('&#47;', '/');
    expect(
      normalizedHtml,
      contains('<figure class="align-center" style="width:50%">'),
    );
    expect(normalizedHtml, contains('assets/plot--abc.png'));
  });

  test('standalone HTML embeds images as data URIs', () async {
    final source = note(
      id: 'note-2',
      title: 'Embedded image',
      content: '![Plot](../../Attachments/plot.png)',
    );
    final payload = await NoteExportComposer(
      readAttachment:
          (_) async => Uint8List.fromList(<int>[137, 80, 78, 71]),
    ).exportNote(
      note: source,
      projectTitle: 'ORF9b',
      format: ChronicleExportFormat.html,
    );

    final html = utf8.decode(payload.bytes);
    final normalizedHtml = html.replaceAll('&#47;', '/');
    expect(normalizedHtml, contains('data:image/png;base64,'));
    expect(normalizedHtml, contains('<!doctype html>'));
  });

  test('project archive rewrites wiki links and lists tasks', () async {
    final first = note(
      id: 'first',
      title: 'First',
      content: 'Continue in [[Second]].',
    );
    final second = note(
      id: 'second',
      title: 'Second',
      content: 'Final result.',
    );
    final project = Project(
      id: 'project-1',
      title: 'ORF9b project',
      emoji: '🧬',
      description: 'Metastable states',
    );
    final task = WorkTask(
      id: 'task-1',
      title: 'Analyze trajectory',
      projectId: project.id,
      status: 'done',
    );

    final payload = await NoteExportComposer(
      readAttachment: (_) async => null,
    ).exportProject(
      project: project,
      notes: <Note>[first, second],
      tasks: <WorkTask>[task],
      format: ChronicleExportFormat.portableArchive,
    );

    final entries = StoredZipArchiveBuilder.readStoredEntries(payload.bytes);
    final firstMarkdown = utf8.decode(entries['notes/First.md']!);
    final readme = utf8.decode(entries['README.md']!);
    expect(firstMarkdown, contains('[Second](Second.md)'));
    expect(readme, contains('- [x] Analyze trajectory'));
    expect(readme, contains('[First](notes/First.md)'));
  });

  test('safe file names remove Windows-forbidden characters', () {
    expect(
      NoteExportComposer.safeFileStem('A:B / C*?', fallback: 'note'),
      'A B C',
    );
    expect(NoteExportComposer.safeFileStem('...', fallback: 'note'), 'note');
  });
}
