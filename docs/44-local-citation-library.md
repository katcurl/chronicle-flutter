# Local citation library — Chronicle 0.24.0

Chronicle stores bibliographic sources as structured local records without adding a new SQL table. The collection is serialized in the existing `app_state` table and is included in Chronicle JSON backups. This keeps the first research-tools release migration-free and reversible.

## Source fields

Each source has a stable internal ID and a user-facing citation key, title, type, authors, year, venue, DOI, PMID, arXiv ID, URL, local PDF path, tags, notes and timestamps. Citation keys are unique case-insensitively. Normalized DOI values are also checked for duplicates.

## Portable Markdown syntax

Inline citations use a compact source format:

```markdown
The conformational ensemble can contain multiple functional states [@Jaffe2005].
```

Multiple citations share one group:

```markdown
[@Jaffe2005; @Smith2023]
```

A bibliography is inserted with:

```markdown
:::bibliography
```

Preview rendering resolves known keys to author-year labels and builds the bibliography in first-use order. Unknown keys remain visible as raw `@key` references. Citation-like text inside fenced code blocks is never interpreted.

## BibTeX safety

Import is preview-first. Entries missing a title or key are reported, and duplicates by citation key or DOI are skipped rather than overwriting local records. Export copies deterministic BibTeX text to the clipboard.

## Scope

The library is included in local database state and JSON backup/restore. Chronicle 0.24.0 deliberately does not add citation records to the LAN change journal, does not copy selected PDFs into the Vault, and does not alter existing notes automatically. These are separate future milestones.
