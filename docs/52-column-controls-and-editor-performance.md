# Column controls and editor performance

Chronicle 0.24.9 completes the visual column workflow and removes repeated
full-document work from ordinary note editing.

## Column management

The visual composer keeps two or three Markdown bodies in the existing
`chronicle-columns` container. A complete column can now be dragged by its
handle. Its body and responsive width move together, so an image, caption,
formula, table or checklist is not separated from the layout chosen for it.

The selected column has a visible border. From its menu the user can duplicate
it while a third slot is available. A blank third column can also be added from
the composer header. Two-column layouts have a direct swap action.

Removing a third column is lossless. Chronicle merges its Markdown with the
nearest neighboring body in the original reading order and only then removes
the empty layout slot. Converting the complete composition back to ordinary
Markdown remains available and unchanged.

## Editing and scrolling stability

Live preview used to parse and rebuild expensive Markdown structures for nearly
every keystroke in split mode. The editor now separates immediate source text
from delayed derived views:

- live preview updates after a short typing pause;
- word count and reading time update on a slower independent cadence;
- complete block parsing waits until cursor activity settles;
- preview refresh is paused during an active scroll gesture;
- a stable scroll controller preserves the visible location;
- top-level Markdown chunks are built lazily as they approach the viewport.

Switching explicitly to preview synchronizes the current source immediately, so
the delayed split-view refresh never causes stale content when changing modes.
The note itself is still saved through the existing explicit save paths.

## Compatibility

No Markdown marker, attachment binary, database table, Vault path, sync payload
or theme setting changes in this release. Existing column blocks and ordinary
notes require no migration.
