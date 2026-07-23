import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'features/appearance/app_appearance.dart';
import 'features/appearance/app_appearance_store.dart';
import 'features/appearance/app_appearance_theme.dart';
import 'services/app_store.dart';
import 'shells/home_shell.dart';

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

class _ChronicleAppState extends State<ChronicleApp>
    with WidgetsBindingObserver {
  late final AppStore store;
  final AppAppearanceStore _appearanceStore = AppAppearanceStore();
  AppAppearancePreferences _appearance = AppAppearancePreferences.defaults();
  File? _backgroundFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = widget.store ?? AppStore.production();
    store.load();
    unawaited(_loadAppearance());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.handleAppResumed();
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await store.flushPendingWrites();
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            themeMode: _appearance.brightnessMode.themeMode,
            theme: buildChronicleTheme(
              Brightness.light,
              _appearance,
              backgroundAvailable: _backgroundFile != null,
            ),
            darkTheme: buildChronicleTheme(
              Brightness.dark,
              _appearance,
              backgroundAvailable: _backgroundFile != null,
            ),
            builder:
                (context, child) => ChronicleBackdrop(
                  backgroundImage:
                      _backgroundFile == null
                          ? null
                          : FileImage(_backgroundFile!),
                  revision: _appearance.backgroundRevision,
                  child: child ?? const SizedBox.shrink(),
                ),
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
    return HomeShell(
      store: store,
      appearance: _appearance,
      backgroundImage:
          _backgroundFile == null ? null : FileImage(_backgroundFile!),
      onAppearanceChanged: _updateAppearance,
    );
  }

  Future<void> _loadAppearance() async {
    AppAppearancePreferences loaded;
    File? backgroundFile;
    try {
      loaded = await _appearanceStore.load();
      backgroundFile = await _appearanceStore.backgroundFileFor(loaded);
    } on Object {
      loaded = AppAppearancePreferences.defaults();
      backgroundFile = null;
    }
    if (!mounted) return;
    setState(() {
      _appearance = loaded;
      _backgroundFile = backgroundFile;
    });
  }

  Future<void> _updateAppearance(AppAppearanceChange change) async {
    final saved = await _appearanceStore.saveChange(change);
    final backgroundFile = await _appearanceStore.backgroundFileFor(saved);
    if (!mounted) return;
    setState(() {
      _appearance = saved;
      _backgroundFile = backgroundFile;
    });
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                    'Не удалось открыть базу Chronicle',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
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
      ),
    );
  }
}
