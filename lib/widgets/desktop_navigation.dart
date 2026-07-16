import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EscapeToClose extends StatelessWidget {
  const EscapeToClose({super.key, required this.child, this.onEscape});

  final Widget child;
  final VoidCallback? onEscape;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _CloseRouteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CloseRouteIntent: CallbackAction<_CloseRouteIntent>(
            onInvoke: (_) {
              final callback = onEscape;
              if (callback != null) {
                callback();
              } else {
                Navigator.maybePop(context);
              }
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class EscapeKeyHint extends StatelessWidget {
  const EscapeKeyHint({super.key, this.label = 'Назад'});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (!_isDesktopPlatform) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Tooltip(
      message: 'Нажми Esc, чтобы вернуться назад',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Esc',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseRouteIntent extends Intent {
  const _CloseRouteIntent();
}

bool get _isDesktopPlatform {
  if (kIsWeb) {
    return true;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}
