import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'features/appearance/app_appearance.dart';
import 'features/appearance/app_appearance_store.dart';
import 'features/appearance/app_appearance_theme.dart';
import 'recovery/recovery_models.dart';
import 'recovery/recovery_service.dart';
import 'screens/recovery_screen.dart';
import 'services/app_store.dart';
import 'shells/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChronicleApp());
}

class ChronicleApp extends StatefulWidget {
  const ChronicleApp({
    super.key,
    this.store,
    this.storeFactory,
    this.recoveryService,
  });

  final AppStore? store;
  final AppStore Function()? storeFactory;
  final RecoveryService? recoveryService;

  @override
  State<ChronicleApp> createState() => _ChronicleAppState();
}

class _ChronicleAppState extends State<ChronicleApp>
    with WidgetsBindingObserver {
  late AppStore store;
  late final AppStore Function()? _storeFactory;
  late final RecoveryService _recoveryService;
  final AppAppearanceStore _appearanceStore = AppAppearanceStore();
  AppAppearancePreferences _appearance = AppAppearancePreferences.defaults();
  File? _backgroundFile;
  RecoveryInspection _recoveryInspection = RecoveryInspection.empty();
  bool _bootstrapping = true;
  String? _startupTechnicalCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _storeFactory =
        widget.storeFactory ??
        (widget.store == null ? AppStore.production : null);
    store = widget.store ?? _storeFactory!.call();
    _recoveryService =
        widget.recoveryService ??
        (widget.store == null ? RecoveryService() : RecoveryService.disabled());
    unawaited(_bootstrap());
    unawaited(_loadAppearance());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_bootstrapping &&
        store.loadError == null &&
        !_recoveryInspection.hasBlockingProblems) {
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
    if (_bootstrapping || !store.ready && store.loadError == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_recoveryInspection.hasBlockingProblems || store.loadError != null) {
      return RecoveryScreen(
        service: _recoveryService,
        initialInspection: _recoveryInspection,
        technicalCode: _startupTechnicalCode,
        onRetry: _bootstrap,
        onRestore: _restoreCandidate,
      );
    }
    return HomeShell(
      store: store,
      appearance: _appearance,
      backgroundImage:
          _backgroundFile == null ? null : FileImage(_backgroundFile!),
      onAppearanceChanged: _updateAppearance,
    );
  }

  Future<void> _bootstrap() async {
    if (mounted) {
      setState(() {
        _bootstrapping = true;
        _startupTechnicalCode = null;
      });
    }
    RecoveryInspection inspection;
    try {
      inspection = await _recoveryService.inspectForStartup();
    } on Object {
      inspection = RecoveryInspection(
        candidates: const <RecoveryCandidate>[
          RecoveryCandidate(
            id: 'preflight-failed',
            kind: RecoveryCandidateKind.startupFailure,
            title: 'Безопасная проверка не завершена',
            description:
                'Chronicle остановил запуск, не изменяя исходные файлы.',
            severity: RecoverySeverity.blocking,
          ),
        ],
      );
      _startupTechnicalCode = 'preflight-unavailable';
    }

    if (!inspection.hasBlockingProblems) {
      await store.load();
      if (store.loadError != null) {
        _startupTechnicalCode = 'database-open-${store.loadError.runtimeType}';
      }
    } else {
      _startupTechnicalCode ??= 'preflight-blocked';
    }

    if (!mounted) return;
    setState(() {
      _recoveryInspection = inspection;
      _bootstrapping = false;
    });
  }

  Future<void> _restoreCandidate(RecoveryCandidate candidate) async {
    final factory = _storeFactory;
    if (factory == null) {
      throw StateError(
        'Для этого экземпляра Chronicle не задана фабрика AppStore.',
      );
    }
    final previousStore = store;
    await previousStore.shutdown();
    previousStore.dispose();
    Object? failure;
    try {
      await _recoveryService.restoreCandidate(candidate);
    } on Object catch (error) {
      failure = error;
    }
    store = factory();
    if (mounted) {
      setState(() {
        _bootstrapping = failure == null;
        if (failure != null) {
          _startupTechnicalCode = 'restore-${failure.runtimeType}';
        }
      });
    }
    if (failure != null) {
      throw StateError('Восстановление остановлено безопасно.');
    }
    await _bootstrap();
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
