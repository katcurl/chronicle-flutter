# Chronicle settings center

Chronicle 0.28.0 consolidates visual and workspace customization behind one
ordinary settings entry. The dedicated palette button is removed from desktop
and compact navigation so color customization no longer competes with primary
navigation actions.

## Settings entry

The navigation now shows a general settings icon. `Ctrl+,` on Windows/Linux and
`Cmd+,` on macOS open the same dialog. The existing direct appearance shortcut,
`Ctrl+Shift+A` / `Cmd+Shift+A`, remains available for users who already rely on
it.

The settings center contains three focused rows:

- **Appearance** shows the current accent palette, surface style and brightness
  mode, then opens the existing live appearance editor.
- **Workspaces** shows the active workspace and its starting section, then opens
  the existing workspace manager.
- **Project appearance** opens Projects, where each project keeps its own theme
  and PNG, JPEG, WebP or GIF icon controls.

This keeps one discoverable entry point without duplicating the actual editors
or adding another persistent preference model.

## Storage and compatibility

The settings center stores no new data. Global appearance, workspaces and
project appearance continue using their existing local SharedPreferences keys,
and project icon files remain in the existing managed application-support
directory. No database, Vault or synchronization migration is required.
