import 'package:chronicle/features/appearance/app_appearance.dart';
import 'package:chronicle/features/settings/app_settings_dialog.dart';
import 'package:chronicle/features/workspaces/workspace_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings center exposes only the existing customization destinations', () {
    expect(AppSettingsDestination.values, <AppSettingsDestination>[
      AppSettingsDestination.appearance,
      AppSettingsDestination.workspaces,
      AppSettingsDestination.projectAppearance,
    ]);
  });

  test('appearance summary names palette, surface and brightness', () {
    const appearance = AppAppearancePreferences(
      accentPalette: ChroniclePalette.red,
      iconPalette: ChroniclePalette.amber,
      backgroundPalette: ChroniclePalette.graphite,
      panelPalette: ChroniclePalette.orange,
      surfaceStyle: ChronicleSurfaceStyle.shiny,
      brightnessMode: ChronicleBrightnessMode.dark,
    );

    expect(
      AppSettingsDialog.appearanceSummary(appearance),
      'Красная · Shiny · Тёмная',
    );
  });

  test('workspace summary includes the active workspace and start section', () {
    final workspace = WorkspaceProfile.defaults()[1];

    expect(
      AppSettingsDialog.workspaceSummary(workspace),
      '🧪 Лаборатория · старт: Заметки',
    );
  });
}
