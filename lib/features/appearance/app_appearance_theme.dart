import 'package:flutter/material.dart';

import 'app_appearance.dart';

ThemeData buildChronicleTheme(
  Brightness brightness,
  AppAppearancePreferences appearance,
) {
  final isLight = brightness == Brightness.light;
  final background = appearance.backgroundPalette.background(brightness);
  final panel = appearance.panelPalette.panel(brightness);
  final accent = _adjustForBrightness(
    appearance.accentPalette.seed,
    brightness,
  );
  final iconAccent = _adjustForBrightness(
    appearance.iconPalette.seed,
    brightness,
  );
  final generated = ColorScheme.fromSeed(
    seedColor: appearance.accentPalette.seed,
    brightness: brightness,
  );
  final panelLow = Color.lerp(panel, background, isLight ? 0.18 : 0.12)!;
  final panelMid = Color.lerp(panel, accent, isLight ? 0.045 : 0.08)!;
  final panelHigh = Color.lerp(panel, accent, isLight ? 0.09 : 0.14)!;
  final panelHighest = Color.lerp(panel, accent, isLight ? 0.15 : 0.22)!;
  final outline = Color.lerp(
    generated.outlineVariant,
    appearance.panelPalette.seed,
    isLight ? 0.12 : 0.2,
  )!;
  final colors = generated.copyWith(
    primary: accent,
    surface: panel,
    surfaceContainerLowest: panel,
    surfaceContainerLow: panelLow,
    surfaceContainer: panelMid,
    surfaceContainerHigh: panelHigh,
    surfaceContainerHighest: panelHighest,
    outlineVariant: outline,
  );
  final style = appearance.surfaceStyle;
  final elevation = switch (style) {
    ChronicleSurfaceStyle.matte => 0.0,
    ChronicleSurfaceStyle.glossy => 1.0,
    ChronicleSurfaceStyle.shiny => 3.0,
  };
  final cardSide = switch (style) {
    ChronicleSurfaceStyle.matte => BorderSide.none,
    ChronicleSurfaceStyle.glossy => BorderSide(
      color: colors.outlineVariant.withValues(alpha: 0.72),
    ),
    ChronicleSurfaceStyle.shiny => BorderSide(
      color: _highlight(panel, brightness).withValues(alpha: 0.78),
    ),
  };

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: background,
    visualDensity: VisualDensity.standard,
    iconTheme: IconThemeData(color: iconAccent),
    primaryIconTheme: IconThemeData(color: iconAccent),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: iconAccent),
      actionsIconTheme: IconThemeData(color: iconAccent),
      titleTextStyle: TextStyle(
        color: colors.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: elevation,
      margin: EdgeInsets.zero,
      shadowColor: colors.shadow.withValues(
        alpha: style == ChronicleSurfaceStyle.shiny ? 0.26 : 0.14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: cardSide,
      ),
      color: panelMid,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: style == ChronicleSurfaceStyle.matte
            ? BorderSide.none
            : BorderSide(color: colors.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panelHigh,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: Colors.transparent,
      indicatorColor: colors.secondaryContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: iconAccent);
        }
        return IconThemeData(color: colors.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: colors.secondaryContainer,
      selectedIconTheme: IconThemeData(color: iconAccent),
      selectedLabelTextStyle: TextStyle(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
      ),
      unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
      unselectedLabelTextStyle: TextStyle(color: colors.onSurfaceVariant),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: iconAccent,
      selectedColor: iconAccent,
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
    extensions: <ThemeExtension<dynamic>>[
      ChronicleAppearanceTheme(
        style: style,
        panelColor: panel,
        panelHighlight: _highlight(panel, brightness),
        panelShadow: _shadow(panel, brightness),
        iconAccent: iconAccent,
        outlineColor: colors.outlineVariant,
      ),
    ],
  );
}

@immutable
class ChronicleAppearanceTheme
    extends ThemeExtension<ChronicleAppearanceTheme> {
  const ChronicleAppearanceTheme({
    required this.style,
    required this.panelColor,
    required this.panelHighlight,
    required this.panelShadow,
    required this.iconAccent,
    required this.outlineColor,
  });

  final ChronicleSurfaceStyle style;
  final Color panelColor;
  final Color panelHighlight;
  final Color panelShadow;
  final Color iconAccent;
  final Color outlineColor;

  @override
  ChronicleAppearanceTheme copyWith({
    ChronicleSurfaceStyle? style,
    Color? panelColor,
    Color? panelHighlight,
    Color? panelShadow,
    Color? iconAccent,
    Color? outlineColor,
  }) {
    return ChronicleAppearanceTheme(
      style: style ?? this.style,
      panelColor: panelColor ?? this.panelColor,
      panelHighlight: panelHighlight ?? this.panelHighlight,
      panelShadow: panelShadow ?? this.panelShadow,
      iconAccent: iconAccent ?? this.iconAccent,
      outlineColor: outlineColor ?? this.outlineColor,
    );
  }

  @override
  ChronicleAppearanceTheme lerp(
    covariant ThemeExtension<ChronicleAppearanceTheme>? other,
    double t,
  ) {
    if (other is! ChronicleAppearanceTheme) return this;
    return ChronicleAppearanceTheme(
      style: t < 0.5 ? style : other.style,
      panelColor: Color.lerp(panelColor, other.panelColor, t)!,
      panelHighlight: Color.lerp(panelHighlight, other.panelHighlight, t)!,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t)!,
      iconAccent: Color.lerp(iconAccent, other.iconAccent, t)!,
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t)!,
    );
  }

  BoxDecoration decoration({
    BorderRadiusGeometry? borderRadius,
    bool emphasized = false,
  }) {
    final radius = borderRadius ?? BorderRadius.zero;
    switch (style) {
      case ChronicleSurfaceStyle.matte:
        return BoxDecoration(color: panelColor, borderRadius: radius);
      case ChronicleSurfaceStyle.glossy:
        return BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.lerp(panelHighlight, panelColor, 0.22)!,
              panelColor,
            ],
          ),
          border: Border.all(
            color: panelHighlight.withValues(alpha: 0.62),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: panelShadow.withValues(alpha: emphasized ? 0.24 : 0.14),
              blurRadius: emphasized ? 22 : 14,
              offset: const Offset(0, 5),
            ),
          ],
        );
      case ChronicleSurfaceStyle.shiny:
        return BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const <double>[0, 0.34, 1],
            colors: <Color>[
              panelHighlight,
              Color.lerp(panelHighlight, panelColor, 0.68)!,
              panelShadow,
            ],
          ),
          border: Border.all(
            color: panelHighlight.withValues(alpha: 0.82),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: panelShadow.withValues(alpha: emphasized ? 0.34 : 0.24),
              blurRadius: emphasized ? 28 : 18,
              offset: const Offset(0, 7),
            ),
          ],
        );
    }
  }
}

class ChroniclePanelSurface extends StatelessWidget {
  const ChroniclePanelSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.emphasized = false,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final bool emphasized;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final appearance = Theme.of(
      context,
    ).extension<ChronicleAppearanceTheme>();
    if (appearance == null) return child;
    final radius = borderRadius ?? BorderRadius.zero;
    return DecoratedBox(
      decoration: appearance.decoration(
        borderRadius: radius,
        emphasized: emphasized,
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            child,
            if (appearance.style == ChronicleSurfaceStyle.shiny)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ChronicleGlitterPainter(
                      sparkleColor: appearance.panelHighlight,
                      accentColor: appearance.iconAccent,
                      emphasized: emphasized,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChronicleGlitterPainter extends CustomPainter {
  const _ChronicleGlitterPainter({
    required this.sparkleColor,
    required this.accentColor,
    required this.emphasized,
  });

  final Color sparkleColor;
  final Color accentColor;
  final bool emphasized;

  static const List<Offset> _points = <Offset>[
    Offset(0.07, 0.18),
    Offset(0.16, 0.72),
    Offset(0.24, 0.34),
    Offset(0.33, 0.84),
    Offset(0.42, 0.13),
    Offset(0.51, 0.58),
    Offset(0.61, 0.27),
    Offset(0.69, 0.77),
    Offset(0.78, 0.42),
    Offset(0.88, 0.16),
    Offset(0.94, 0.67),
    Offset(0.13, 0.44),
    Offset(0.37, 0.49),
    Offset(0.57, 0.89),
    Offset(0.83, 0.88),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = sparkleColor.withValues(alpha: emphasized ? 0.52 : 0.34)
      ..style = PaintingStyle.fill;
    final accentPaint = Paint()
      ..color = accentColor.withValues(alpha: emphasized ? 0.42 : 0.26)
      ..strokeWidth = emphasized ? 1.2 : 0.9
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < _points.length; index++) {
      final normalized = _points[index];
      final center = Offset(
        normalized.dx * size.width,
        normalized.dy * size.height,
      );
      final radius = index % 3 == 0 ? 1.45 : 0.8;
      canvas.drawCircle(center, radius, dotPaint);
      if (index % 4 == 0) {
        final arm = emphasized ? 4.0 : 3.0;
        canvas.drawLine(
          center.translate(-arm, 0),
          center.translate(arm, 0),
          accentPaint,
        );
        canvas.drawLine(
          center.translate(0, -arm),
          center.translate(0, arm),
          accentPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChronicleGlitterPainter oldDelegate) {
    return sparkleColor != oldDelegate.sparkleColor ||
        accentColor != oldDelegate.accentColor ||
        emphasized != oldDelegate.emphasized;
  }
}

Color _adjustForBrightness(Color color, Brightness brightness) {
  return brightness == Brightness.light
      ? Color.lerp(color, Colors.black, 0.04)!
      : Color.lerp(color, Colors.white, 0.2)!;
}

Color _highlight(Color panel, Brightness brightness) {
  return Color.lerp(
    panel,
    Colors.white,
    brightness == Brightness.light ? 0.72 : 0.18,
  )!;
}

Color _shadow(Color panel, Brightness brightness) {
  return Color.lerp(
    panel,
    Colors.black,
    brightness == Brightness.light ? 0.13 : 0.34,
  )!;
}
