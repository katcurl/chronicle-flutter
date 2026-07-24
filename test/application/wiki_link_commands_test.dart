import 'package:chronicle/application/notes/wiki_link_commands.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wiki links prefer the unique note in the source folder', () {
    final source = _note('source', 'Source', folder: 'daily');
    final nearby = _note('nearby', 'Target', folder: 'daily');
    final distant = _note('distant', 'Target', folder: 'archive');
    final data = AppData(
      projects: <Project>[Project(id: 'project', title: 'Project', emoji: 'P')],
      tasks: <WorkTask>[],
      notes: <Note>[source, nearby, distant],
      entries: <TimeEntry>[],
    );
    final commands = WikiLinkCommands(
      repository: InMemoryAppRepository(initialData: data),
      currentData: () => data,
      syncNoteLinks: (_, {notify = true}) async {},
      scheduleSync: () {},
      scheduleVaultMirror: () {},
      notifyListeners: () {},
    );

    expect(commands.resolveTarget('Target', source: source)?.id, nearby.id);
    expect(commands.targetFor(nearby), 'id:${nearby.id}');
  });
}

Note _note(String id, String title, {required String folder}) => Note(
  id: id,
  projectId: 'project',
  title: title,
  body: '',
  folderPath: folder,
);
