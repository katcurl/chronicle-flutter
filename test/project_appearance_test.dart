import 'dart:typed_data';

import 'package:chronicle/features/appearance/app_appearance.dart';
import 'package:chronicle/features/projects/project_appearance.dart';
import 'package:chronicle/features/projects/project_appearance_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project appearance inherits the complete global appearance by default', () {
    final global = AppAppearancePreferences.preset(
      ChroniclePalette.orange,
      surfaceStyle: ChronicleSurfaceStyle.glossy,
      brightnessMode: ChronicleBrightnessMode.dark,
    );

    final project = ProjectAppearancePreferences.defaults();

    expect(project.inheritsGlobal, isTrue);
    expect(project.effectiveAppearance(global), global);
  });

  test('custom project colors keep the global brightness mode', () {
    final global = AppAppearancePreferences.preset(
      ChroniclePalette.graphite,
      brightnessMode: ChronicleBrightnessMode.light,
    );
    const project = ProjectAppearancePreferences(
      inheritsGlobal: false,
      accentPalette: ChroniclePalette.red,
      iconPalette: ChroniclePalette.amber,
      backgroundPalette: ChroniclePalette.graphite,
      panelPalette: ChroniclePalette.orange,
      surfaceStyle: ChronicleSurfaceStyle.shiny,
    );

    final effective = project.effectiveAppearance(global);

    expect(effective.usesCoordinatedPalette, isFalse);
    expect(effective.accentPalette, ChroniclePalette.red);
    expect(effective.iconPalette, ChroniclePalette.amber);
    expect(effective.backgroundPalette, ChroniclePalette.graphite);
    expect(effective.panelPalette, ChroniclePalette.orange);
    expect(effective.surfaceStyle, ChronicleSurfaceStyle.shiny);
    expect(effective.brightnessMode, ChronicleBrightnessMode.light);
  });

  test('project appearance map round-trips icon metadata safely', () {
    const original = ProjectAppearancePreferences(
      inheritsGlobal: false,
      accentPalette: ChroniclePalette.amber,
      iconPalette: ChroniclePalette.orange,
      backgroundPalette: ChroniclePalette.graphite,
      panelPalette: ChroniclePalette.amber,
      surfaceStyle: ChronicleSurfaceStyle.glossy,
      iconFileName: 'project_demo_1.gif',
      iconRevision: 4,
      backgroundFileName: 'project_demo_bg.gif',
      backgroundRevision: 2,
      wallpaperOpacity: 0.8,
      wallpaperOverlay: 0.25,
      panelOpacity: 0.62,
      panelBlurSigma: 14,
      sparkleIntensity: 1.4,
    );

    final decoded = ProjectAppearanceStore.decode(
      ProjectAppearanceStore.encode(
        const <String, ProjectAppearancePreferences>{'demo': original},
      ),
    );

    expect(decoded['demo'], original);
  });

  test('icon validation detects animated GIF by content', () {
    final bytes = Uint8List.fromList(<int>[
      ...'GIF89a'.codeUnits,
      0x01,
      0x00,
      0x01,
      0x00,
    ]);

    final selection = ProjectIconSelection.validate(
      bytes: bytes,
      originalName: 'icon.bin',
    );

    expect(selection.extension, 'gif');
  });

  test('icon validation rejects unsupported content', () {
    expect(
      () => ProjectIconSelection.validate(
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        originalName: 'not-an-image.txt',
      ),
      throwsFormatException,
    );
  });


  test('project background validation detects PNG by content', () {
    final selection = ProjectBackgroundSelection.validate(
      bytes: Uint8List.fromList(<int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]),
      originalName: 'background.bin',
    );

    expect(selection.extension, 'png');
  });
}
