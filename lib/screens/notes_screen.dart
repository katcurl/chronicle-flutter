import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import '../services/app_store.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.toLowerCase();
    final notes = widget.store.data.notes
        .where(
          (note) =>
              note.title.toLowerCase().contains(normalizedQuery) ||
              note.body.toLowerCase().contains(normalizedQuery),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
        actions: [
          IconButton(
            onPressed: widget.store.data.projects.isEmpty ? null : _add,
            icon: const Icon(Icons.note_add_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Поиск по базе знаний',
              leading: const Icon(Icons.search_rounded),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? const Center(child: Text('Заметок пока нет'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final note = notes[index];
                      final project = widget.store.data.projects.firstWhere(
                        (item) => item.id == note.projectId,
                      );
                      return Card(
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => NoteEditor(
                                store: widget.store,
                                note: note,
                              ),
                            ),
                          ).then((_) => setState(() {})),
                          leading: CircleAvatar(child: Text(project.emoji)),
                          title: Text(note.title),
                          subtitle: Text(
                            '${note.tags.map((tag) => '#$tag').join(' ')}\n'
                            'Обновлено ${note.updatedAt.day}.${note.updatedAt.month}',
                            maxLines: 2,
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _add() {
    final project = widget.store.data.projects.first;
    final note = Note(
      id: const Uuid().v4(),
      title: 'Новая заметка',
      projectId: project.id,
      body: '# Новая заметка\n\n',
    );
    widget.store.addNote(note);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NoteEditor(store: widget.store, note: note),
      ),
    ).then((_) => setState(() {}));
  }
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.store,
    required this.note,
  });

  final AppStore store;
  final Note note;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController title;
  late final TextEditingController body;
  bool preview = false;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.note.title);
    body = TextEditingController(text: widget.note.body);
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  void save() {
    widget.note.title =
        title.text.trim().isEmpty ? 'Без названия' : title.text.trim();
    widget.note.body = body.text;
    widget.store.updateNote(widget.note);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) => save(),
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: () {
                save();
                setState(() => preview = !preview);
              },
              icon: Icon(
                preview ? Icons.edit_rounded : Icons.visibility_outlined,
              ),
            ),
            PopupMenuButton<String>(
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Удалить'),
                ),
              ],
              onSelected: (value) {
                if (value != 'delete') return;
                widget.store.deleteNote(widget.note.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            save();
            widget.store.startTimer(
              description: 'Работа над ${widget.note.title}',
              projectId: widget.note.projectId,
              noteId: widget.note.id,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Таймер запущен')),
            );
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Работать'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  controller: title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Название',
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: preview
                    ? _Preview(data: body.text)
                    : TextField(
                        controller: body,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          height: 1.55,
                        ),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(18),
                          border: InputBorder.none,
                          hintText: 'Markdown, LaTeX, [[ссылки]]…',
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final parts = data.split(
      RegExp(r'(\\\[[\s\S]*?\\\]|\$\$[\s\S]*?\$\$)'),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: parts.where((part) => part.isNotEmpty).map((part) {
        final trimmed = part.trim();
        final isDisplayMath =
            (trimmed.startsWith(r'\[') && trimmed.endsWith(r'\]')) ||
                (trimmed.startsWith(r'$$') && trimmed.endsWith(r'$$'));
        if (isDisplayMath) {
          final tex = trimmed.substring(2, trimmed.length - 2);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                tex,
                textStyle: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          );
        }
        return MarkdownBody(data: part, selectable: true);
      }).toList(),
    );
  }
}
