# Safe wiki-link renaming

Chronicle 0.23.4 adds a preview-first rename workflow for notes that already
have incoming wiki links.

## Safety rules

- The note title is not mass-rewritten during ordinary background saves.
- The user opens an explicit preview from the title row or the save action.
- Only references that currently resolve unambiguously to the renamed note are
  included in the plan.
- Ambiguous references are reported and block the safe batch action until the user repairs them.
- Every affected note receives a persistent `NoteVersion` before modification.
- The completed operation exposes an immediate undo action.

Updated links use the portable form:

```text
[[id:<note-id>|Readable title]]
```

The stable ID prevents later duplicate titles or project moves from redirecting
the link. Existing aliases and heading anchors are preserved.

## Link health

The Notes screen includes a link-health dialog. It distinguishes:

- missing targets, which can be created beside the source note;
- ambiguous targets, which require an explicit choice;
- exact ID links whose target was deleted, which are left for manual repair.

Repairs create a safety version of the source note before replacing the link.
No database migration is required.
