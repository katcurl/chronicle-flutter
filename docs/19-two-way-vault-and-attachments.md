# Chronicle v0.14 — Two-way Vault and attachments

Chronicle v0.14 turns the Markdown Vault from a one-way mirror into a guarded
bidirectional workspace.

## Import flow

- Chronicle stores the SHA-256 hash of every managed note in
  `.chronicle/vault-index.json`.
- A scan compares the baseline hash, the current database rendering and the
  current Markdown file.
- External-only edits are safe import candidates.
- Simultaneous database and file edits are conflicts.
- Missing managed files never delete database notes; Chronicle offers to
  recreate them.
- New Markdown files under `Notes/` can be imported as new notes.
- Moves and renames are detected through `chronicle_id` and the file path.

Chronicle pauses automatic mirror writes while unresolved external changes
exist, preventing silent data loss.

## Conflict choices

- **Keep Chronicle** rewrites the file from the database.
- **Use file version** saves the current database note in history, then imports
  the Markdown file.
- **Keep both** preserves Chronicle and imports the file as a separate note.

## Attachments

The note editor can copy a selected file into `Attachments/`. Files receive a
stable content-hash suffix to avoid collisions. Chronicle inserts a relative
Markdown link; local images are rendered from the selected Vault on native
platforms.

No cloud storage, account or external server is introduced.
