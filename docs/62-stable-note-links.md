# Stable note links and mention review

Chronicle 0.26.6 extends the existing wiki-link system without changing the
Vault format or database schema.

## Exact-ID links

Links created through the picker or autocomplete are stored as:

```markdown
[[id:note-uuid|Readable title]]
```

The visible title stays human-readable while navigation uses the immutable note
ID. Existing `[[Title]]` and `[[Project :: Title]]` links remain supported.

## Link picker

The editor toolbar and `Ctrl+Shift+K` / `Cmd+Shift+K` open a searchable picker.
Search covers title, project, folder, note type and tags. Up to 24 notes can be
inserted in one action, either inline or as a Markdown list.

## Unlinked mentions

The note menu can scan the current unsaved Markdown for unique note titles that
are not already links. Fenced code, inline code, existing wiki links and normal
Markdown links are excluded. Duplicate titles are intentionally skipped because
the intended target would be ambiguous.

Selected mentions are replaced from the end of the document toward the start,
which preserves all recorded offsets. The editor cursor is adjusted by the
length of preceding replacements.

## Compatibility and safety

- No new database table or migration.
- No automatic background scan while typing.
- Existing notes are unchanged until the user confirms insertion or conversion.
- One mention review is bounded to 80 occurrences.
- Safe rename, backlinks and the knowledge graph continue to use the existing
  note-link index.
