# Personal editor profiles

Chronicle 0.27.1 adds local editor profiles without changing the application theme,
Vault format, note Markdown, synchronization payloads or database schema.

## Built-in profiles

- **Scientific** keeps the Markdown toolbar, link suggestions, note context and a
  bounded reading width suitable for figures and tables.
- **Focus** uses a wider system font, spacious padding and hides secondary chrome.
- **Compact** uses the full available width and denser spacing.

Profiles can be created, duplicated, renamed and removed. Each profile stores:

- editor font, size and line height;
- maximum text width or full-width layout;
- preview text scale and interface density;
- the mode used when a note is opened;
- visibility of the title field, Markdown toolbar, link suggestions, note context
  panel and timer action.

The active profile is saved in SharedPreferences under
`chronicle_note_editor_profiles_v1`. It is a local UI preference and is not
written into the Vault or synchronized with note content.
