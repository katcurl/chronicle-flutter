import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/app_store.dart';
import 'local_intelligence.dart';

class LocalIntelligenceScreen extends StatefulWidget {
  const LocalIntelligenceScreen({
    super.key,
    required this.store,
    required this.project,
  });
  final AppStore store;
  final Project project;
  static Future<void> show(
    BuildContext context, {
    required AppStore store,
    required Project project,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LocalIntelligenceScreen(store: store, project: project),
    ),
  );
  @override
  State<LocalIntelligenceScreen> createState() => _State();
}

class _State extends State<LocalIntelligenceScreen> {
  final engine = LocalIntelligenceEngine(),
      disk = const IntelligenceIndexStore(),
      query = TextEditingController();
  IntelligenceIndex? index;
  List<IntelligenceHit> hits = [];
  IntelligenceAnswer? answer;
  bool busy = true;
  List<Note> get notes =>
      widget.store.data.notes
          .where((n) => n.projectId == widget.project.id)
          .toList();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final old = await disk.read(widget.project.id), dg = engine.digest(notes);
    index =
        old != null && old.digest == dg
            ? old
            : engine.build(widget.project, notes);
    if (old == null || old.digest != dg) await disk.write(index!);
    if (mounted) setState(() => busy = false);
  }

  Future<void> rebuild() async {
    setState(() => busy = true);
    index = engine.build(widget.project, notes);
    await disk.write(index!);
    if (mounted) {
      setState(() {
        busy = false;
        hits = [];
        answer = null;
      });
    }
  }

  Future<void> remove() async {
    await disk.delete(widget.project.id);
    if (mounted) {
      setState(() {
        index = null;
        hits = [];
        answer = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = index;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Локальный интеллектуальный поиск'),
        actions: [
          IconButton(
            tooltip: 'Перестроить индекс',
            onPressed: busy ? null : rebuild,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') remove();
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить локальный индекс'),
                  ),
                ],
          ),
        ],
      ),
      body:
          busy
              ? const Center(child: CircularProgressIndicator())
              : i == null
              ? _Empty(onBuild: rebuild)
              : DefaultTabController(
                length: 5,
                child: Column(
                  children: [
                    MaterialBanner(
                      leading: const Icon(Icons.memory),
                      content: Text(
                        'Только на этом устройстве · ${i.docs.length} заметок. Chronicle ничего не переписывает автоматически.',
                      ),
                      actions: const [],
                    ),
                    const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: 'Поиск и вопросы'),
                        Tab(text: 'Похожие'),
                        Tab(text: 'Противоречия'),
                        Tab(text: 'Термины'),
                        Tab(text: 'История'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _search(i),
                          _similar(i),
                          _conflicts(i),
                          _terms(i),
                          _history(i),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _search(IntelligenceIndex i) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      TextField(
        controller: query,
        decoration: const InputDecoration(
          labelText: 'Смысловой запрос или вопрос',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          FilledButton.tonal(
            onPressed:
                () => setState(() {
                  hits = engine.search(i, query.text);
                  answer = null;
                }),
            child: const Text('Найти заметки'),
          ),
          FilledButton.tonal(
            onPressed:
                () => setState(() {
                  answer = engine.answer(i, query.text);
                  hits = [];
                }),
            child: const Text('Ответить по проекту'),
          ),
        ],
      ),
      if (answer != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ответ из локального индекса',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SelectableText(answer!.text),
                const SizedBox(height: 8),
                Text(
                  'Источники: ${answer!.sources.map((e) => e.doc.title).join(' · ')}',
                ),
              ],
            ),
          ),
        ),
      for (final h in hits) _Hit(h),
    ],
  );
  Widget _similar(IntelligenceIndex i) => _Similar(index: i, engine: engine);
  Widget _conflicts(IntelligenceIndex i) {
    final c = engine.conflicts(i);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Это кандидаты на проверку, а не автоматические вердикты.'),
        if (c.isEmpty)
          const Card(
            child: ListTile(title: Text('Явных кандидатов не найдено.')),
          ),
        for (final x in c)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${x.left.title} ↔ ${x.right.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('«${x.a}»'),
                  Text('«${x.b}»'),
                  Text(x.reason),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _terms(IntelligenceIndex i) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in engine.terms(i).entries)
          Chip(label: Text('${e.key} · ${e.value}')),
      ],
    ),
  );
  Widget _history(IntelligenceIndex i) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text(
        'Суммаризация истории эксперимента',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Хронология извлекается из заметок; исходный текст не меняется.',
      ),
      const SizedBox(height: 12),
      SelectableText(engine.history(i)),
    ],
  );
}

class _Hit extends StatelessWidget {
  const _Hit(this.h);
  final IntelligenceHit h;
  @override
  Widget build(BuildContext c) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Text('${(h.score * 100).round()}')),
      title: Text(h.doc.title),
      subtitle: Text('${h.snippet}\nСовпало: ${h.shared.join(', ')}'),
      isThreeLine: true,
    ),
  );
}

class _Similar extends StatefulWidget {
  const _Similar({required this.index, required this.engine});
  final IntelligenceIndex index;
  final LocalIntelligenceEngine engine;
  @override
  State<_Similar> createState() => _SimilarState();
}

class _SimilarState extends State<_Similar> {
  String? id;
  @override
  Widget build(BuildContext c) {
    final sim =
        id == null
            ? <IntelligenceHit>[]
            : widget.engine.similar(widget.index, id!);
    final links = widget.engine.links(widget.index);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: id,
          decoration: const InputDecoration(labelText: 'Похожие на заметку'),
          items: [
            for (final d in widget.index.docs)
              DropdownMenuItem(value: d.id, child: Text(d.title)),
          ],
          onChanged: (v) => setState(() => id = v),
        ),
        for (final h in sim) _Hit(h),
        const SizedBox(height: 14),
        const Text(
          'Возможные связи',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        for (final x in links)
          Card(
            child: ListTile(
              title: Text('${x.left.title} ↔ ${x.right.title}'),
              subtitle: Text(
                '${x.shared.join(', ')} · ${(x.score * 100).round()}%',
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onBuild});
  final VoidCallback onBuild;
  @override
  Widget build(BuildContext c) => Center(
    child: FilledButton.icon(
      onPressed: onBuild,
      icon: const Icon(Icons.build),
      label: const Text('Построить локальный индекс'),
    ),
  );
}
