import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/appearance/app_appearance.dart';
import '../features/appearance/app_appearance_dialog.dart';
import '../features/appearance/app_appearance_store.dart';
import '../features/appearance/app_appearance_theme.dart';
import '../features/projects/project_appearance_store.dart';
import '../features/settings/app_settings_dialog.dart';
import '../features/settings/release_readiness_dialog.dart';
import '../features/workspaces/workspace_manager_dialog.dart';
import '../features/workspaces/workspace_preferences_store.dart';
import '../features/workspaces/workspace_profile.dart';
import '../navigation/app_section.dart';
import '../screens/dashboard_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/tasks_screen.dart';
import '../services/app_store.dart';
import '../widgets/desktop_context_panel.dart';
import '../widgets/responsive_breakpoints.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.store,
    required this.appearance,
    required this.backgroundImage,
    required this.onAppearanceChanged,
  });

  final AppStore store;
  final AppAppearancePreferences appearance;
  final ImageProvider<Object>? backgroundImage;
  final Future<void> Function(AppAppearanceChange change) onAppearanceChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final WorkspacePreferencesStore _workspaceStore =
      WorkspacePreferencesStore();
  final ProjectAppearanceController _projectAppearanceController =
      ProjectAppearanceController();
  WorkspacePreferences _workspacePreferences = WorkspacePreferences.defaults();
  AppSection section = AppSection.today;

  WorkspaceProfile get activeWorkspace =>
      _workspacePreferences.activeProfile;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWorkspacePreferences());
    unawaited(_projectAppearanceController.load());
  }

  @override
  void dispose() {
    _projectAppearanceController.dispose();
    super.dispose();
  }

  int get index => section.index;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.digit1, control: true):
            () => _select(AppSection.today),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true):
            () => _select(AppSection.projects),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true):
            () => _select(AppSection.tasks),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true):
            () => _select(AppSection.notes),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true):
            () => _select(AppSection.insights),
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
            () => _select(AppSection.today),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
            () => _select(AppSection.projects),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
            () => _select(AppSection.tasks),
        const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
            () => _select(AppSection.notes),
        const SingleActivator(LogicalKeyboardKey.digit5, meta: true):
            () => _select(AppSection.insights),
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): _start,
        const SingleActivator(LogicalKeyboardKey.keyT, meta: true): _start,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            () => unawaited(_undo()),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            () => unawaited(_undo()),
        const SingleActivator(
          LogicalKeyboardKey.keyW,
          control: true,
          shift: true,
        ): () => unawaited(_openWorkspaceManager()),
        const SingleActivator(
          LogicalKeyboardKey.keyW,
          meta: true,
          shift: true,
        ): () => unawaited(_openWorkspaceManager()),
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            () => unawaited(_openSettings()),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            () => unawaited(_openSettings()),
        const SingleActivator(
          LogicalKeyboardKey.keyA,
          control: true,
          shift: true,
        ): () => unawaited(_openAppearance()),
        const SingleActivator(
          LogicalKeyboardKey.keyA,
          meta: true,
          shift: true,
        ): () => unawaited(_openAppearance()),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < ChronicleBreakpoints.navigationRail) {
              return _buildCompact();
            }
            return _buildWide(constraints.maxWidth);
          },
        ),
      ),
    );
  }

  Widget _buildCompact() {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: _pages(),
      bottomNavigationBar: ChroniclePanelSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: colors.outlineVariant),
            SizedBox(
              height: 46,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _workspaceSwitcher(compact: false),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: widget.store.canUndo
                        ? 'Отменить: ${widget.store.nextUndoLabel} (Ctrl+Z)'
                        : 'Нет действий для отмены',
                    onPressed: widget.store.canUndo
                        ? () => unawaited(_undo())
                        : null,
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Настройки (Ctrl+,)',
                    onPressed: () => unawaited(_openSettings()),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            NavigationBar(
              backgroundColor: Colors.transparent,
              selectedIndex: index,
              onDestinationSelected:
                  (value) => _select(AppSection.values[value]),
              destinations:
                  AppSection.values
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: item.label,
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWide(double width) {
    final workspace = activeWorkspace;
    final showContextPanel =
        width >= ChronicleBreakpoints.contextPanel &&
        workspace.showContextPanel;
    final extended =
        width >= ChronicleBreakpoints.extendedNavigationRail &&
        workspace.extendedNavigation;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: ChroniclePanelSurface(
              child: NavigationRail(
                backgroundColor: Colors.transparent,
                selectedIndex: index,
                onDestinationSelected:
                    (value) => _select(AppSection.values[value]),
                extended: extended,
                minWidth: 80,
                minExtendedWidth: 224,
                groupAlignment: -0.68,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (extended)
                        const _ExtendedWordmark()
                      else
                        const _CompactWordmark(),
                      const SizedBox(height: 12),
                      _workspaceSwitcher(compact: !extended),
                    ],
                  ),
                ),
                trailing: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        tooltip: widget.store.canUndo
                            ? 'Отменить: ${widget.store.nextUndoLabel} (Ctrl+Z)'
                            : 'Нет действий для отмены',
                        onPressed: widget.store.canUndo
                            ? () => unawaited(_undo())
                            : null,
                        icon: const Icon(Icons.undo_rounded),
                      ),
                      const SizedBox(height: 8),
                      IconButton.filledTonal(
                        tooltip: 'Настройки (Ctrl+,)',
                        onPressed: () => unawaited(_openSettings()),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                      const SizedBox(height: 8),
                      IconButton.filledTonal(
                        tooltip:
                            widget.store.activeStartedAt == null
                                ? 'Начать таймер (Ctrl+T)'
                                : 'Остановить таймер',
                        onPressed:
                            widget.store.activeStartedAt == null
                                ? _start
                                : widget.store.stopTimer,
                        icon: Icon(
                          widget.store.activeStartedAt == null
                              ? Icons.play_arrow_rounded
                              : Icons.stop_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                destinations:
                    AppSection.values
                        .map(
                          (item) => NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant),
          Expanded(child: _pages()),
          if (showContextPanel) ...[
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: colors.outlineVariant,
            ),
            DesktopContextPanel(
              store: widget.store,
              section: section,
              workspace: workspace,
              onStartTimer: _start,
            ),
          ],
        ],
      ),
    );
  }

  Widget _pages() {
    final pages = <Widget>[
      DashboardScreen(
        store: widget.store,
        onOpenTask: (_) => _select(AppSection.tasks),
        onStart: _start,
      ),
      ProjectsScreen(
        store: widget.store,
        appearanceController: _projectAppearanceController,
        globalAppearance: widget.appearance,
      ),
      TasksScreen(store: widget.store),
      NotesScreen(
        store: widget.store,
        appearanceController: _projectAppearanceController,
        globalAppearance: widget.appearance,
      ),
      InsightsScreen(store: widget.store),
    ];

    return IndexedStack(index: index, children: pages);
  }

  void _select(AppSection value) {
    if (section == value) return;
    setState(() => section = value);
  }

  Future<void> _loadWorkspacePreferences() async {
    WorkspacePreferences loaded;
    try {
      loaded = await _workspaceStore.load();
    } on Object {
      loaded = WorkspacePreferences.defaults();
    }
    if (!mounted) return;
    setState(() {
      _workspacePreferences = loaded;
      section = loaded.activeProfile.startSection;
    });
  }

  Future<void> _activateWorkspace(String id) async {
    WorkspaceProfile? profile;
    for (final candidate in _workspacePreferences.profiles) {
      if (candidate.id == id) {
        profile = candidate;
        break;
      }
    }
    if (profile == null) return;
    final selectedProfile = profile;
    final next = _workspacePreferences.copyWith(activeWorkspaceId: id);
    setState(() {
      _workspacePreferences = next;
      section = selectedProfile.startSection;
    });
    await _saveWorkspacePreferences(next);
  }

  Future<void> _openWorkspaceManager() async {
    final result = await WorkspaceManagerDialog.show(
      context,
      preferences: _workspacePreferences,
    );
    if (!mounted || result == null) return;
    setState(() {
      _workspacePreferences = result;
      section = result.activeProfile.startSection;
    });
    await _saveWorkspacePreferences(result);
  }

  Future<void> _openSettings() async {
    final destination = await AppSettingsDialog.show(
      context,
      appearance: widget.appearance,
      activeWorkspace: activeWorkspace,
    );
    if (!mounted || destination == null) return;
    if (destination == AppSettingsDestination.appearance) {
      await _openAppearance();
      return;
    }
    if (destination == AppSettingsDestination.workspaces) {
      await _openWorkspaceManager();
      return;
    }
    if (destination == AppSettingsDestination.reliability) {
      await ReleaseReadinessDialog.show(context, store: widget.store);
      return;
    }
    _select(AppSection.projects);
  }

  Future<void> _openAppearance() async {
    final result = await AppAppearanceDialog.show(
      context,
      preferences: widget.appearance,
      existingBackgroundImage: widget.backgroundImage,
    );
    if (!mounted || result == null) return;
    try {
      await widget.onAppearanceChanged(result);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить оформление: $error')),
      );
    }
  }

  Future<void> _saveWorkspacePreferences(WorkspacePreferences value) async {
    try {
      await _workspaceStore.save(value);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить интерфейс: $error')),
      );
    }
  }

  Widget _workspaceSwitcher({required bool compact}) {
    final workspace = activeWorkspace;
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Рабочее пространство',
      onSelected: (value) {
        if (value == '__manage__') {
          unawaited(_openWorkspaceManager());
        } else {
          unawaited(_activateWorkspace(value));
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        for (final profile in _workspacePreferences.profiles)
          PopupMenuItem<String>(
            value: profile.id,
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    profile.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                Expanded(child: Text(profile.name)),
                if (profile.id == _workspacePreferences.activeWorkspaceId)
                  Icon(Icons.check_rounded, color: colors.primary),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__manage__',
          child: Row(
            children: [
              Icon(Icons.tune_rounded),
              SizedBox(width: 12),
              Text('Настроить пространства'),
            ],
          ),
        ),
      ],
      child: ChroniclePanelSurface(
        borderRadius: BorderRadius.circular(compact ? 14 : 12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 9 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(workspace.emoji, style: const TextStyle(fontSize: 18)),
              if (!compact) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Text(
                    workspace.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down_rounded, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _undo() async {
    try {
      final label = await widget.store.undoLastAction();
      if (!mounted || label == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Отменено: $label')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отменить действие: $error')),
      );
    }
  }

  Future<void> _start() async {
    if (widget.store.activeProjects.isEmpty) return;

    final controller = TextEditingController();
    var projectId = widget.store.activeProjects.first.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder:
          (sheetContext) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              6,
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
                  onSubmitted: (_) {
                    _startSelectedTimer(
                      sheetContext,
                      controller.text,
                      projectId,
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: projectId,
                  decoration: const InputDecoration(labelText: 'Проект'),
                  items:
                      widget.store.activeProjects
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
                    onPressed:
                        () => _startSelectedTimer(
                          sheetContext,
                          controller.text,
                          projectId,
                        ),
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

  void _startSelectedTimer(
    BuildContext sheetContext,
    String description,
    String projectId,
  ) {
    widget.store.startTimer(
      description: description.trim(),
      projectId: projectId,
    );
    Navigator.pop(sheetContext);
  }
}

class _CompactWordmark extends StatelessWidget {
  const _CompactWordmark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Chronicle',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(15),
        ),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.auto_stories_rounded, color: colors.onPrimary),
        ),
      ),
    );
  }
}

class _ExtendedWordmark extends StatelessWidget {
  const _ExtendedWordmark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.auto_stories_rounded, color: colors.onPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Chronicle',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
