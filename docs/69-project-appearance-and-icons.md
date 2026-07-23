# Project appearance and custom icons

Chronicle 0.27.5 adds a local visual identity for each project without changing
project records, note Markdown, the Vault format or synchronization payloads.

## Project-specific appearance

A project may either inherit Chronicle's global appearance or select one of the
existing coordinated palettes or independently select accent, icon, background
and panel colors, plus one of the Matte, Glossy or Shiny surface styles. The
global system/light/dark mode remains authoritative, so opening a project never
forces an unexpected brightness change.

The selected project appearance is used for:

- the project card in the Projects screen;
- the project card on the Notes overview;
- the complete project detail route;
- note workspaces belonging to the project.

Returning to a general Chronicle screen restores the global appearance.

## PNG, JPEG, WebP and GIF icons

The project editor accepts PNG, JPEG, WebP and GIF files up to 10 MB. Chronicle
validates the file signature rather than trusting only its extension. The file
is copied into Chronicle's application-support directory, so moving or deleting
the original download does not break the project icon.

Flutter renders GIF files with their animation in project cards, the project
header and note metadata. Removing a custom icon returns the project to its
emoji fallback and deletes the managed file after the new preference state is
saved.

## Glitter Shiny surfaces

The Shiny style now adds a deterministic layer of small reflective points and
star-shaped sparkles above the panel gradient. The overlay ignores pointer
input and does not change panel geometry, layout, scrolling or accessibility
semantics.

## Storage and safety

Project appearance metadata is stored in SharedPreferences under
`chronicle_project_appearance_v1`. Managed icon files are stored in the
`project_icons` application-support directory. No database migration is
required.
