import 'package:flutter/material.dart';

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
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor:
          isLight ? const Color(0xFFF8F7FC) : const Color(0xFF111116),
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        color: isLight ? Colors.white : const Color(0xFF1B1B22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? const Color(0xFFF1EFF7) : const Color(0xFF24242C),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor:
            isLight ? colors.surfaceContainerLowest : const Color(0xFF1B181F),
        indicatorColor: colors.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: colors.secondaryContainer,
        selectedIconTheme: IconThemeData(color: colors.onSecondaryContainer),
        selectedLabelTextStyle: TextStyle(
          color: colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(color: colors.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(false),
        radius: const Radius.circular(99),
        thickness: const WidgetStatePropertyAll(6),
        thumbColor: WidgetStatePropertyAll(
          colors.onSurfaceVariant.withValues(alpha: 0.35),
        ),
      ),
    );
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
