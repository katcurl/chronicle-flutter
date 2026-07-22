import 'package:chronicle/features/workspaces/workspace_preferences_store.dart';
import 'package:chronicle/features/workspaces/workspace_profile.dart';
import 'package:chronicle/navigation/app_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default workspaces include overview, laboratory and focus', () {
    final preferences = WorkspacePreferences.defaults();

    expect(preferences.profiles.map((profile) => profile.id), <String>[
      'overview',
      'laboratory',
      'focus',
    ]);
    expect(preferences.activeProfile.startSection, AppSection.today);
    expect(preferences.activeProfile.showContextPanel, isTrue);
  });

  test('workspace preferences survive JSON round trip', () {
    final laboratory = WorkspaceProfile.defaults()[1].copyWith(
      panelOrder: const <WorkspacePanel>[
        WorkspacePanel.metrics,
        WorkspacePanel.timer,
        WorkspacePanel.recentSessions,
        WorkspacePanel.shortcuts,
        WorkspacePanel.localFirst,
      ],
      visiblePanels: const <WorkspacePanel>{
        WorkspacePanel.metrics,
        WorkspacePanel.timer,
      },
      extendedNavigation: false,
    );
    final source = WorkspacePreferences.normalized(
      activeWorkspaceId: laboratory.id,
      profiles: <WorkspaceProfile>[laboratory],
    );

    final decoded = WorkspacePreferencesStore.decode(
      WorkspacePreferencesStore.encode(source),
    );

    expect(decoded.activeWorkspaceId, laboratory.id);
    expect(decoded.activeProfile.name, 'Лаборатория');
    expect(decoded.activeProfile.extendedNavigation, isFalse);
    expect(decoded.activeProfile.panelOrder.first, WorkspacePanel.metrics);
    expect(decoded.activeProfile.visiblePanels, <WorkspacePanel>{
      WorkspacePanel.metrics,
      WorkspacePanel.timer,
    });
  });

  test('invalid stored data falls back without duplicate panels', () {
    const raw = '''
      {
        "activeWorkspaceId": "missing",
        "profiles": [
          {
            "id": "custom",
            "name": "Custom",
            "emoji": "C",
            "startSection": "unknown",
            "showContextPanel": true,
            "extendedNavigation": false,
            "panelOrder": ["timer", "timer", "unknown"],
            "visiblePanels": ["timer", "unknown"]
          }
        ]
      }
    ''';

    final decoded = WorkspacePreferencesStore.decode(raw);

    expect(decoded.activeWorkspaceId, 'custom');
    expect(decoded.activeProfile.startSection, AppSection.notes);
    expect(decoded.activeProfile.panelOrder, WorkspacePanel.values);
    expect(decoded.activeProfile.visiblePanels, <WorkspacePanel>{
      WorkspacePanel.timer,
    });
  });

  test('malformed JSON returns safe defaults', () {
    final decoded = WorkspacePreferencesStore.decode('{not json');

    expect(decoded.activeWorkspaceId, 'overview');
    expect(decoded.profiles, hasLength(3));
  });
}
