# Personal workspaces

Chronicle 0.26.5 introduces local interface profiles called **workspaces**.
A workspace changes how Chronicle is arranged without moving or rewriting any
notes, projects, tasks, attachments or Vault files.

## Built-in profiles

The first launch provides three editable profiles:

- **Overview** opens Today and keeps the complete context panel visible.
- **Laboratory** opens Notes and shows the timer, recent sessions and metrics.
- **Focus** opens Notes with compact navigation and no right context panel.

They are starting points rather than protected presets. A user may rename,
duplicate, reorder or delete them as long as at least one profile remains.

## Per-workspace settings

Each profile stores only UI preferences:

- name and emoji;
- section opened when the profile is selected;
- compact or extended navigation on sufficiently wide windows;
- visibility of the right context panel;
- visibility and order of the timer, metrics, recent sessions, shortcut hints
  and local-first notice.

The right panel still follows responsive breakpoints and is hidden when the
window is too narrow, even when a workspace enables it.

## Storage and safety

Profiles are saved in local `SharedPreferences` under
`chronicle_workspaces_v1`. They are not written into the Vault and do not
participate in LAN synchronization or project export. Corrupt or unsupported
stored data falls back to the built-in profiles.

Switching a workspace never saves, migrates or modifies note content. It only
changes the active application section and shell layout.
