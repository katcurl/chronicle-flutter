# Scientific figures, tables and cross-references

Chronicle 0.24.2+55 adds note-local scientific numbering without a database migration or hidden document conversion.

## Figures

A managed Markdown image becomes a scientific figure only after the user enables **Numbered scientific figure** in the existing image settings dialog. Chronicle stores the stable figure ID alongside the existing width, alignment and caption metadata:

```markdown
![RMSD](../../Attachments/rmsd.png "chronicle-image width=75 align=center caption=RMSD%20trajectory figure=orf9b-rmsd")
```

Ordinary images remain ordinary images. Figure numbers are recalculated from document order while the stable ID remains unchanged.

## Tables

Chronicle creates a standard GitHub-Flavored Markdown table with a readable marker immediately above it:

```markdown
<!-- chronicle-table id=md-conditions caption=MD%20conditions -->
| Parameter | Value |
| --- | --- |
| Temperature | 300 K |
```

The marker and table are treated as one structural block by block controls and drag reordering.

## Cross-references

Portable reference tokens are:

```markdown
см. @fig(orf9b-rmsd)
см. @tbl(md-conditions)
```

Preview resolves these tokens to the current figure or table number. Moving an object changes the visible number without rewriting the token. Missing targets and duplicate IDs remain visible as warnings rather than being silently redirected.

## Safety boundaries

- Numbering is local to one note.
- Existing Markdown is not migrated automatically.
- Figure and table IDs must use Latin letters, digits, dots, hyphens or underscores.
- The feature does not change the citation library, wiki links, database schema, Vault attachments or LAN synchronization.
