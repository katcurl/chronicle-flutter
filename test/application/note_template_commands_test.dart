import 'package:chronicle/application/notes/note_template_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom template commands normalize tags before publication', () async {
    final commands = NoteTemplateCommands(notifyListeners: () {});

    final template = await commands.create(
      title: ' Protocol ',
      icon: '',
      noteType: '',
      content: '# Protocol',
      defaultTags: const <String>[' Lab ', 'lab', ''],
    );

    expect(template.title, 'Protocol');
    expect(template.icon, '📝');
    expect(template.noteType, 'note');
    expect(template.defaultTags, <String>['Lab']);
    expect(commands.customTemplates, <Object>[template]);
  });
}
