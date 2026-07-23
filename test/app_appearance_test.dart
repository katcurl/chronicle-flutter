import 'dart:typed_data';

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
    expect(preferences.backgroundFileName, isNull);
    expect(preferences.panelOpacity, 1);
    expect(preferences.panelBlurSigma, 0);
    expect(preferences.sparkleIntensity, 1);
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
      backgroundFileName: 'background_1.gif',
      backgroundRevision: 3,
      wallpaperOpacity: 0.72,
      wallpaperOverlay: 0.31,
      panelOpacity: 0.68,
      panelBlurSigma: 18,
      sparkleIntensity: 1.6,
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
    expect(decoded.backgroundFileName, 'background_1.gif');
    expect(decoded.backgroundRevision, 3);
    expect(decoded.wallpaperOpacity, 0.72);
    expect(decoded.wallpaperOverlay, 0.31);
    expect(decoded.panelOpacity, 0.68);
    expect(decoded.panelBlurSigma, 18);
    expect(decoded.sparkleIntensity, 1.6);
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


  test('background validation detects GIF content and rejects unknown bytes', () {
    final gif = AppBackgroundSelection.validate(
      bytes: Uint8List.fromList(<int>[
        ...'GIF89a'.codeUnits,
        0x01,
        0x00,
        0x01,
        0x00,
      ]),
      originalName: 'wallpaper.bin',
    );

    expect(gif.extension, 'gif');
    expect(
      () => AppBackgroundSelection.validate(
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        originalName: 'wallpaper.txt',
      ),
      throwsFormatException,
    );
  });
}
