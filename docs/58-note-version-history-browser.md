# Note version history browser

Chronicle 0.26.2+68 extends the existing `NoteVersion` snapshots. It does not introduce a second history store: the same database records created by manual saves and safety operations are displayed through a dedicated comparison interface.

## Current-state comparison

The browser compares a selected snapshot with the editor state that is currently visible, including unsaved title, Markdown, tags, status, folder, note type and custom properties. Opening history therefore does not require an autosave and does not mutate the note.

For ordinary notes Chronicle uses a line-based longest-common-subsequence diff. To keep very large documents responsive, the comparison has a bounded matrix size. Above that limit Chronicle preserves the common prefix and suffix and represents the changed middle as removals followed by additions. No source text is omitted from the browser.

## Restoration safety

Selecting a version never changes the note. Restoration requires an explicit button and a second confirmation dialog. The existing restoration path remains responsible for creating a snapshot of the current state with the reason **Перед восстановлением** before applying the selected version. As a result, restoring an old state remains reversible from the same history.

## Storage boundaries

The feature reuses the existing note-version database records and does not alter the Vault mirror, attachment layout, synchronization payloads or backup format. Existing versions require no migration. Search and diff results are computed in memory only while the dialog is open.
