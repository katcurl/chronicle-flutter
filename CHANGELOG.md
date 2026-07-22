# Changelog

## 0.25.0+64

- Added direct image pasting from the Windows clipboard into the Markdown editor with `Ctrl+V`.
- Added a dedicated **Вставить изображение из буфера** toolbar action for discoverability.
- Converted native Windows DIB/DIBv5 clipboard images and copied image files to PNG without changing the original clipboard contents.
- Stored pasted images through the existing content-addressed Vault attachment pipeline, including deduplication, the attachment index, backup support and LAN synchronization.
- Inserted the generated Markdown image reference at the current cursor or selection while preserving ordinary text paste when no clipboard image is present.
- Kept clipboard work asynchronous and guarded against concurrent paste operations so the editor remains responsive.
- Preserved themes, Vault layout, synchronization formats, database schema, existing attachments and existing notes without migration.
- Added deterministic tests for clipboard file names and direct in-memory PNG attachment import.

## 0.24.10+63

- Stabilized image resizing in preview and split mode by retaining the requested width until the updated Markdown is rendered, eliminating the visible snap back to the old size.
- Coalesced high-frequency pointer updates to at most one layout change per animation frame so dragging large images no longer overwhelms the UI thread.
- Synchronized image-size edits with the live preview immediately while keeping the note dirty for the existing explicit save paths instead of forcing a full AppStore save on every resize.
- Added a dedicated attachment refresh signal so ordinary note edits no longer cause every Vault image in the open note to be read from disk again.
- Kept attachment refreshes for actual attachment imports, LAN synchronization, Vault application and backup restoration.
- Preserved image binaries, responsive Markdown metadata, themes, Vault layout, synchronization payloads, database schema and existing notes without migration.
- Added deterministic tests for attachment refresh isolation and stable image-resize rendering behavior.

## 0.24.9+62

- Added direct drag-and-drop reordering for complete columns while preserving their Markdown content and responsive width.
- Added a clearly highlighted active column, one-click two-column swapping, a third-column add action and per-column duplication.
- Added safe column removal that merges the removed Markdown into the nearest neighbor in reading order instead of deleting it.
- Debounced live Markdown preview, note statistics and full block parsing so normal typing no longer triggers repeated expensive document work.
- Paused pending preview refreshes during active scrolling, preserved the preview scroll controller across Markdown updates and resumed rendering only after scrolling settles.
- Changed the top-level preview to lazy chunk construction and isolated it behind a repaint boundary to reduce work for long notes with images, equations and column blocks.
- Preserved the existing portable Markdown column format, themes, Vault files, attachments, synchronization, database schema and existing notes without migration.
- Added deterministic tests for delayed refresh coalescing, scroll-time pausing, immediate synchronization, column movement, duplication and lossless removal.

## 0.24.8+61

- Replaced the layout-only column dialog with a visual Markdown composer for each two- or three-column body.
- Added one-click layouts for figure-left/text-right, text-left/figure-right, equal two-column and equal three-column arrangements.
- Added separate per-column editors with safe left/right content movement before the block is inserted or updated.
- Preserved selected editor text in the composer, automatically separated a leading selected image from following explanatory text, and made existing column blocks editable without exposing Chronicle marker comments.
- Kept automatic merge behavior when reducing three columns to two and added a placeholder without losing content when expanding to three.
- Preserved draggable preview dividers, responsive vertical stacking, image metadata, Markdown portability, themes, Vault files, synchronization, database schema and existing notes.
- Added deterministic tests for content expansion, content merging and Markdown preservation across layout changes.

## 0.24.7+60

- Added a compact image-size menu directly on managed images in note preview.
- Added one-click responsive presets for 25%, 50%, 75% and 100% width without changing the image file.
- Added keyboard-accessible 5% decrease and increase actions for precise sizing.
- Added a clear **Сбросить размер** action in the image settings dialog that restores 100% width while preserving alignment, caption and scientific figure ID.
- Centralized supported width presets, limits and step size in the existing Markdown image syntax layer.
- Kept old Markdown images compatible and preserved image proportions, Vault attachments, synchronization, themes, database schema and existing notes.
- Added deterministic tests for the public image-width limits, presets, step and normalization behavior.

## 0.24.6+59

- Added locally persisted user-created note templates without a database migration.
- Added creation, editing and deletion of custom templates with a title, icon, note type, Markdown body and default tags.
- Added **Сохранить заметку как шаблон** in the Markdown editor, preserving the current note content, type, tags and custom properties as template defaults.
- Added **Мои шаблоны** management from the editor toolbar and the new-note sheet.
- Included custom templates in both new-note creation and the safe in-editor template picker.
- Kept all built-in templates immutable and preserved existing notes when a custom template is edited or deleted.
- Stored custom templates only in Chronicle local preferences; Vault files, synchronization, attachments, database schema and visual themes remain unchanged.
- Added deterministic tests for JSON round-tripping, corrupt-payload recovery and in-memory create/update/delete behavior.

## 0.24.5+58

- Added a **Лабораторный шаблон** command to the Markdown editor toolbar.
- Added an in-editor picker for all six laboratory templates with a complete Markdown preview before application.
- Kept appending to the end as the safe default for non-empty notes and required a separate confirmation before either appending or replacing content.
- Added immediate undo when the editor text has not been changed after template application.
- Kept the current note type, tags, properties, title and project unchanged; no database migration was introduced.
- Preserved the visual theme, Vault files, synchronization, attachments and all notes unless a user explicitly applies a template in the editor.
- Added deterministic tests for empty-note insertion, safe append, explicit replacement and newline normalization.

## 0.24.4+57

- Added six built-in laboratory note templates: laboratory day, experiment, sample passport, protein expression and purification, NMR experiment, and buffer or solution.
- Added structured default metadata, checklists and portable Markdown tables without introducing a database migration.
- Kept all existing templates and existing notes unchanged.
- Preserved the visual theme, Vault files, synchronization, attachments and application data.
- Added deterministic tests for template identifiers, metadata, headings, labels and icons.

## 0.24.3+56

- Added the missing scientific figure ID to the Markdown round-trip test fixture.
- Kept production image parsing and serialization unchanged because figure IDs were already written and restored correctly.
- Preserved existing notes, images, citations, wiki links, Vault files, synchronization and themes.

## 0.24.2+55

- Added optional scientific IDs to managed images so selected images can become automatically numbered figures without changing ordinary images.
- Added portable Markdown tables with readable Chronicle metadata, captions and numbering independent from figure numbering.
- Added stable in-note references through `@fig(id)` and `@tbl(id)` that update their displayed number after objects move or are deleted.
- Added a table-creation dialog, an object picker for cross-references and a read-only report of figures, tables, duplicate IDs and broken links.
- Kept each scientific table together as one safe Markdown block for moving, duplicating, deleting and drag reordering.
- Added duplicate-ID prevention in figure and table dialogs while preserving visible warnings for malformed hand-edited Markdown.
- Kept existing images, citations, wiki links, Vault files, LAN synchronization, database schema and visual themes unchanged.
- Added deterministic tests for numbering, reference rendering, broken and ambiguous targets, fenced-code safety, figure metadata and complete table blocks.

## 0.24.1+54

- Migrated the PDF chooser to the static `FilePicker.pickFiles` API required by file_picker 12.
- Added explicit braces to the BibTeX parser loops required by Chronicle's strict Flutter lint configuration.
- Restored clean `flutter analyze` execution without changing citation parsing, source-library data, Markdown, Vault files, synchronization, wiki links, or themes.

## 0.24.0+53

- Added a separate local research-source library reachable from the Notes screen.
- Added articles, books, conference papers, theses and web sources with authors, year, venue, DOI, PMID, arXiv ID, URL, local PDF path, tags and notes.
- Added citation-key and DOI duplicate protection before manual saves and BibTeX imports.
- Added preview-first BibTeX import, warning-only duplicate handling, and BibTeX export through the clipboard.
- Added multi-source citation insertion in portable Markdown form such as `[@Jaffe2005; @Smith2023]`.
- Added the `:::bibliography` block, which renders only sources actually cited in the current note and preserves first-use order.
- Added author-year citation rendering in preview while keeping the raw Markdown unchanged.
- Stored the source library in Chronicle backup JSON and local database state without a schema migration or changes to wiki links, Vault files or LAN attachment synchronization.
- Added deterministic tests for citation parsing, fenced-code safety, bibliography order, BibTeX round-tripping and repository persistence.

## 0.23.4+52

- Added a preview-first workflow for renaming notes that already have incoming wiki links.
- Rewrites only links that resolve unambiguously to the renamed note and blocks the safe batch action until ambiguous references are reviewed.
- Converts updated references to exact `[[id:note-id|label]]` targets so later title changes cannot silently redirect them.
- Preserves custom labels and heading anchors while refreshing automatic title labels.
- Creates persistent note versions before every affected note is changed and offers immediate undo after the operation.
- Added a global link-health dialog for missing and ambiguous links, with direct creation or explicit target selection.
- Added exact-link repair with a safety version and no database migration.
- Ignored Chronicle patch backups in Git so local recovery files no longer clutter `git status`.
- Added deterministic tests for exact-ID links, anchors, rename planning, apply/undo behavior, and link-health classification.

## 0.23.3+51

- Added the required project emoji to two wiki-navigation test fixtures.
- Restored clean `flutter analyze` execution without changing production wiki-link behavior.
- Kept all user-selected project emojis unrestricted; the two symbols are test data only.
- Preserved notes, Markdown, the knowledge map, Vault files, synchronization, themes, and application data unchanged.

## 0.23.2+50

- Added lightweight `[[` autocomplete that rebuilds only its suggestion strip instead of the complete note workspace.
- Kept wiki links clickable in preview and added readable `[[Project :: Note]]` qualification for duplicate titles across projects.
- Added safe duplicate-title resolution: same-folder and same-project notes are preferred, while unresolved ambiguity opens an explicit chooser instead of selecting an arbitrary note.
- Added backlink context snippets, clearer outgoing-link locations, and a direct Create action for missing targets.
- Made the knowledge map rely on resolved note IDs so ambiguous links are reported as unresolved rather than connected to the first matching title.
- Preserved Markdown portability, existing notes, block editing, themes, Vault files, attachments, and synchronization without a database migration.
- Added deterministic tests for autocomplete, aliases, qualified targets, backlink snippets, duplicate-title resolution, and ambiguous graph links.

## 0.23.1+49

- Removed the redundant `dart:ui` import from the knowledge-map layout test.
- Restored clean `flutter analyze` execution on Flutter 3.44 where unnecessary imports are fatal in GitHub Actions.
- Kept the knowledge map, Markdown, Vault, synchronization, themes, and application behavior unchanged.

## 0.23.0+48

- Added a read-only interactive knowledge map built from Chronicle's existing `[[wiki links]]` and backlink index.
- Grouped notes by project in deterministic clusters without adding a graph package, database migration, or background animation.
- Added pan, zoom, project filtering, search highlighting, connection counts, unresolved-link counts, and direct note opening.
- Kept Markdown, block editing, columns, Vault files, synchronization, themes, and note persistence unchanged.
- Added deterministic layout tests for node separation, resolved, hidden and missing targets, duplicate edges, and self-links.

## 0.22.3+47

- Migrated the block organizer from Flutter's deprecated `onReorder` callback to `onReorderItem`.
- Removed the obsolete manual downward-index correction because Flutter 3.44 now supplies the adjusted insertion index.
- Kept the separate confirmation dialog, delayed mobile drag handle, undo behavior, Markdown serialization, and Vault data unchanged.
- Restored clean `flutter analyze` execution on Flutter 3.44 with fatal deprecation diagnostics enabled.

## 0.22.2+46

- Added a separate drag-and-drop block organizer instead of placing gesture layers over the Markdown text field.
- Reordered paragraphs, headings, lists, images, formulas, fenced code, dividers, and complete Chronicle column groups as intact units.
- Applied the new order only after explicit confirmation; cancelling the dialog leaves the note byte-for-byte unchanged.
- Preserved every block body, leading and trailing text, and the existing separator sequences between block slots.
- Added an immediate undo action after applying a reordered block list.
- Kept the existing up/down controls as the precise fallback and avoided any new listeners on editor scrolling or cursor movement.
- Added deterministic tests for distant reordering, selection relocation, invalid plans, and unchanged plans.

## 0.22.1+45

- Fixed editor stutter and visual shaking introduced by the block-controls toolbar.
- Stopped selection-only controller notifications from rebuilding the entire note workspace and marking the note dirty.
- Cached parsed Markdown blocks and delayed reparsing until typing pauses briefly instead of parsing the whole note on every cursor event.
- Kept the current-block chip at a stable width so toolbar buttons no longer shift while the cursor moves between block types.
- Updated split preview and note statistics independently so they remain live without rebuilding the complete workspace.
- Replaced linear current-block lookup with binary search and added a large-document regression test.

## 0.22.0+44

- Added safe block-aware controls to the Markdown editor without changing the portable note format.
- Recognized paragraphs, headings, lists, checklists, quotes, images, display formulas, fenced code, dividers, and Chronicle column groups.
- Added toolbar actions to move the current block up or down, duplicate it, copy its raw Markdown, and delete it with an undo action.
- Added loss-safe conversion between paragraph, heading, bulleted-list, checklist, and quote blocks.
- Kept images, code, formulas, and column groups protected from destructive type conversion.
- Added deterministic parser and edit-operation tests for complex Markdown blocks.

## 0.21.7+43

- Added explicit cancellation for active manual LAN synchronization on both devices.
- Added automatic per-file retry for transient Wi-Fi, VPN, timeout, and connection-reset failures.
- Made upload, metadata, and tombstone commands idempotent so a lost response can be retried safely.
- Kept successfully transferred files in the Vault; repeating the same offer recalculates the manifest and continues with the remaining files.
- Added retry-attempt progress messages and a cancellation-specific recovery explanation.
- Added deterministic tests for cancellation and selective retry behavior.

## 0.21.6+42

- Added live LAN sync progress for journal rounds and attachment transfers.
- Both host and scanning devices show the current attachment name, item count, and transferred bytes.
- Expanded the final sync report with attachment counts, bytes, deletions, and conflicts.
- Added a retry action that reuses the current QR offer after transient Wi-Fi or VPN failures.
- Added clearer local-network, timeout, and checksum error messages.
- Added deterministic tests for sync progress calculations.

## 0.21.5+41

- removed the duplicate whole-preview rebuild when attachment storage changes; each Vault image now refreshes independently;
- added an injectable attachment-byte loader so the refresh widget test is deterministic on Linux and Windows runners;
- replaced the real file-I/O and `runAsync` loop that could deadlock until the ten-minute test timeout;
- kept production Vault reads, checksum validation and LAN synchronization unchanged.

## 0.21.4+40

- Remote Vault images now keep their own byte state instead of depending on `FutureBuilder` completion timing.
- A completed `dart:io` read explicitly schedules the widget rebuild, so a synchronized image replaces the placeholder in an already-open note.
- The cross-platform widget test now targets the exact remote image and fallback widgets.

## 0.21.3+39

- made the remote-image widget test wait for asynchronous Vault file I/O before asserting the refreshed preview;
- kept the production image refresh listener from 0.21.2 unchanged;
- prevented GitHub Actions from reporting a false failure when the file read completes after `pumpAndSettle` has already stopped.

## 0.21.2+38

- fixed reloading of Vault images received through LAN sync while a note is already open;
- made each Vault-backed image listen directly for store notifications and replace its cached read future;
- kept the remote-image widget regression test enabled on both Windows and Linux runners.

## 0.21.1+37

- refreshed open note previews after synchronized attachment files arrive;
- made remote images re-resolve from the local Vault after the final sync report;
- restarted the Android QR camera after a failed pairing or sync attempt;
- preferred physical Wi-Fi and Ethernet interfaces over VPN and virtual adapters in QR offers;
- added regression tests for Vault image refresh and VPN-aware LAN address ordering.

## 0.21.0+36

- added two-way LAN transfer of missing attachment binaries between trusted devices;
- verified every received file against the signed SHA-256 and byte length before atomic Vault storage;
- synchronized attachment tombstones and metadata-only deduplicated records;
- prevented automatic overwrite when a managed path contains different content;
- added attachment byte and file counters to sync reports and reliability diagnostics;
- updated the signed LAN protocol to `chronicle-sync-v3`;
- added integration tests for bidirectional attachment transfer and Vault checksum enforcement.

## 0.20.1+35

- added column content reordering from the existing layout dialog;
- added safe conversion of a column block back to ordinary Markdown;
- kept two-to-three column expansion and three-to-two merging in one dialog;
- added clearer management controls and a preview tooltip;
- preserved images, captions, formulas and links while columns are reordered or unwrapped;
- added tests for content order validation and Markdown conversion.

## 0.20.0+34

- fixed the Windows build failure in the three-column layout editor;
- declared the right-column width before redistributing space between columns;
- restored GitHub Actions analysis, tests and Windows packaging for note columns.

## 0.20.0+33

- added portable two- and three-column blocks to Markdown notes;
- added column insertion and layout controls to the editor toolbar;
- added draggable column dividers in note preview;
- preserved images, captions, formulas, links and Markdown inside columns;
- stacked columns vertically on narrow windows;
- kept column syntax readable outside Chronicle through HTML comments.

## 0.19.3+32

- fixed image size, alignment and caption settings being lost after switching between editor and preview;
- image presentation metadata is now persisted immediately after attachment, resizing or configuration;
- switching editor modes now safely flushes the current note buffer without creating a history version.

## 0.19.3

- added responsive image sizing from 20% to 100%;
- added quick image sizes at 25%, 50%, 75% and 100%;
- added left, center and right image alignment;
- added optional captions below images;
- added direct mouse resizing in note preview;
- kept original attachment binaries unchanged and stored only presentation metadata in Markdown.

## 0.19.2

- added signed attachment manifests to trusted LAN sync;
- added deterministic plans for missing binaries, metadata-only records,
  tombstones and path conflicts;
- prevented missing local binaries from being advertised to peers;
- added attachment work counters to sync reports and reliability events;
- updated the signed journal protocol to `chronicle-sync-v2`;
- kept binary transfer disabled until atomic write and checksum verification
  are implemented.

## 0.7.0

- migrated structured data from SharedPreferences to SQLite;
- added one-time legacy data import;
- added repository abstraction and in-memory test repository;
- persisted active timer state between app restarts;
- added JSON backup and restore through the clipboard;
- added soft deletion support for notes;
- added database error recovery screen;
- added model, store and widget tests;
- updated Android APK workflow for API 36.

## 0.6.0

- added Chronicle Foundation documentation;
- established product, architecture, data and design specifications.
