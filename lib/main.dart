import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/tasks_screen.dart';
import 'services/app_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChronicleApp());
}

class ChronicleApp extends StatefulWidget {
  const ChronicleApp({super.key, this.store});

  final AppStore? store;

  @override
  State<ChronicleApp> createState() => _ChronicleAppState();
}

class _ChronicleAppState extends State<ChronicleApp> {
  late final AppStore store;

  @override
  void initState() {
    super.initState();
    store = widget.store ?? AppStore.production();
    store.load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder:
          (_, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Chronicle',
            themeMode: ThemeMode.system,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            home: _home(),
          ),
    );
  }

  Widget _home() {
    if (!store.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (store.loadError != null) {
      return _DatabaseErrorScreen(error: store.loadError!, onRetry: store.load);
    }
    return HomeShell(store: store);
  }

  ThemeData _theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor:
          brightness == Brightness.light
              ? const Color(0xFFF8F7FC)
              : const Color(0xFF111116),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        color:
            brightness == Brightness.light
                ? Colors.white
                : const Color(0xFF1B1B22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            brightness == Brightness.light
                ? const Color(0xFFF1EFF7)
                : const Color(0xFF24242C),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        store: widget.store,
        onOpenTask: (_) => setState(() => index = 2),
        onStart: _start,
      ),
      ProjectsScreen(store: widget.store),
      TasksScreen(store: widget.store),
      NotesScreen(store: widget.store),
      InsightsScreen(store: widget.store),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Сегодня',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Проекты',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Задачи',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Заметки',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Отчёты',
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    if (widget.store.data.projects.isEmpty) return;

    final controller = TextEditingController();
    var projectId = widget.store.data.projects.first.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              22,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Начать работу',
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Над чем работаешь?',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: projectId,
                  items:
                      widget.store.data.projects
                          .map(
                            (project) => DropdownMenuItem<String>(
                              value: project.id,
                              child: Text('${project.emoji} ${project.title}'),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) projectId = value;
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      widget.store.startTimer(
                        description: controller.text.trim(),
                        projectId: projectId,
                      );
                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Запустить таймер'),
                  ),
                ),
              ],
            ),
          ),
    );

    controller.dispose();
  }
}

class _DatabaseErrorScreen extends StatelessWidget {
  const _DatabaseErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storage_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 18),
                Text(
                  'Не удалось открыть локальную базу',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
