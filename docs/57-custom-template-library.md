# Custom template library

Chronicle 0.26.1+67 expands the existing local custom-template feature into a portable and searchable library. The built-in templates remain immutable and are not mixed into the management list.

## Categories and search

Every custom template can have an optional category such as **Лаборатория**, **Учёба**, **Протоколы** or any user-defined value. Existing templates load with an empty category and appear under **Без категории** without a migration.

The library searches across template titles, categories, note types, tags and saved custom properties. A category filter can be combined with the text query. Results are sorted by category and then title; this order affects only the library view and does not rewrite stored templates.

## Duplication

The item menu can duplicate a template before it is edited. The copy receives a new internal ID and a collision-safe title such as **Копия — Название** or **Копия 2 — Название**. Markdown, icon, category, note type, tags and custom-property defaults are preserved.

## Import and export

The library can export either one template or the complete custom collection to a UTF-8 JSON file. The bundle has an explicit Chronicle format identifier and version. Import also accepts the unwrapped JSON list used by the earlier local store so manually preserved 0.24.6-era data remains recoverable.

Imported templates always receive new internal IDs. Exact copies already present in the library are skipped, so importing the same file repeatedly does not create duplicate entries. Unknown bundle formats and unsupported versions are rejected before local preferences are changed.

## Storage boundaries

Categories are added to the existing versioned SharedPreferences JSON. No database table, Vault file or synchronization payload is introduced. Import and export occur only after an explicit user action through the system file picker. Existing notes and templates are never rewritten automatically.
