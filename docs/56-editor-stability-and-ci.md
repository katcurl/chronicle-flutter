# Editor stability and pinned CI

Chronicle 0.25.2+66 is a stabilization release. It does not change the Vault
format or migrate existing notes.

## Undo and redo

The Markdown editor now keeps its own bounded history because Chronicle changes
text both through normal typing and through structured commands. Inserted
images, templates, tables, columns, citations and block operations therefore
participate in the same history as keyboard edits.

Rapid typing is grouped into one history entry after a short pause. Every entry
stores the cursor or selection. A new edit after undo discards the obsolete redo
branch. Reloading a renamed note or restoring a saved version starts a clean
history session.

Controls are available in the editor toolbar and through `Ctrl+Z`, `Ctrl+Y` and
`Ctrl+Shift+Z`.

## Scrolling and persistence

The editor keeps its vertical scroll offset while switching between editor,
preview and split modes. Switching modes no longer performs a synchronous
AppStore update. Dirty content is saved after two seconds without edits, and a
pending save is postponed while the editor or preview is actively scrolling.
Explicit save, leaving the note and operations that already require persistence
continue to save immediately.

## CI toolchain

The Windows and Android workflows use Flutter 3.44.7 explicitly instead of the
moving `stable` head. The Windows workflow also cancels an older build for the same branch when a
newer run starts.
