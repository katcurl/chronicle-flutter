import 'package:chronicle/features/appearance/app_appearance.dart';
import 'package:chronicle/features/appearance/app_appearance_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default appearance preserves the original violet identity', () {
    final preferences = AppAppearancePreferences.defaults();

    expect(preferences.accentPalette, ChroniclePalette.violet);
    expect(preferences.iconPalette, ChroniclePalette.violet);
    expect(preferences.backgroundPalette, ChroniclePalette.violet);
    expect(preferences.panelPalette, ChroniclePalette.violet);
    expect(preferences.surfaceStyle, ChronicleSurfaceStyle.matte);
    expect(preferences.brightnessMode, ChronicleBrightnessMode.system);
  });

  test('coordinated preset applies one palette without changing mode', () {
    final preferences = AppAppearancePreferences.preset(
      ChroniclePalette.orange,
      surfaceStyle: ChronicleSurfaceStyle.glossy,
      brightnessMode: ChronicleBrightnessMode.dark,
    );

    expect(preferences.usesCoordinatedPalette, isTrue);
    expect(preferences.accentPalette, ChroniclePalette.orange);
    expect(preferences.iconPalette, ChroniclePalette.orange);
    expect(preferences.backgroundPalette, ChroniclePalette.orange);
    expect(preferences.panelPalette, ChroniclePalette.orange);
    expect(preferences.surfaceStyle, ChronicleSurfaceStyle.glossy);
    expect(preferences.brightnessMode, ChronicleBrightnessMode.dark);
  });

  test('independent colors survive JSON encoding and decoding', () {
    const original = AppAppearancePreferences(
      accentPalette: ChroniclePalette.red,
      iconPalette: ChroniclePalette.amber,
      backgroundPalette: ChroniclePalette.graphite,
      panelPalette: ChroniclePalette.orange,
      surfaceStyle: ChronicleSurfaceStyle.shiny,
      brightnessMode: ChronicleBrightnessMode.light,
    );

    final decoded = AppAppearanceStore.decode(
      AppAppearanceStore.encode(original),
    );

    expect(decoded.accentPalette, ChroniclePalette.red);
    expect(decoded.iconPalette, ChroniclePalette.amber);
    expect(decoded.backgroundPalette, ChroniclePalette.graphite);
    expect(decoded.panelPalette, ChroniclePalette.orange);
    expect(decoded.surfaceStyle, ChronicleSurfaceStyle.shiny);
    expect(decoded.brightnessMode, ChronicleBrightnessMode.light);
    expect(decoded.usesCoordinatedPalette, isFalse);
  });

  test('unknown and corrupt values recover to safe defaults', () {
    final partiallyUnknown = AppAppearanceStore.decode(
      '{"accentPalette":"missing","iconPalette":"blue",'
      '"backgroundPalette":"missing","panelPalette":"green",'
      '"surfaceStyle":"missing","brightnessMode":"missing"}',
    );
    final corrupt = AppAppearanceStore.decode('{not-json');

    expect(partiallyUnknown.accentPalette, ChroniclePalette.violet);
    expect(partiallyUnknown.iconPalette, ChroniclePalette.blue);
    expect(partiallyUnknown.backgroundPalette, ChroniclePalette.graphite);
    expect(partiallyUnknown.panelPalette, ChroniclePalette.green);
    expect(partiallyUnknown.surfaceStyle, ChronicleSurfaceStyle.matte);
    expect(
      partiallyUnknown.brightnessMode,
      ChronicleBrightnessMode.system,
    );
    expect(
      AppAppearanceStore.encode(corrupt),
      AppAppearanceStore.encode(AppAppearancePreferences.defaults()),
    );
  });
}
