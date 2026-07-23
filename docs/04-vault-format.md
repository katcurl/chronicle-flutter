# Stable Chronicle Vault format (v2)

The Chronicle Vault remains understandable without Chronicle and usable in editors such as Obsidian, Sublime Text, Typora or a plain-text editor. Chronicle 1.0 freezes the current manifest/index contract as Vault format version 2.

## Compatibility header

`manifest.json` contains at least:

```json
{
  "format": "chronicle-vault",
  "version": 2,
  "minimumReaderVersion": 1,
  "stableSince": "1.0.0",
  "unknownFrontmatterPolicy": "preserve",
  "conflictPolicy": "never-silently-overwrite"
}
```

A Chronicle build that supports only an older format must open a newer Vault read-only. It must never rewrite the manifest merely to make the version appear compatible.

## Managed structure

```text
Chronicle Vault/
  Projects/
    <project>/
      Notes/
        <note>.md
  References/
    library.bib
  Templates/
  Attachments/
  Archive/
  manifest.json
  .chronicle/
    vault-index.json
    attachments-index.json
    operation-journal/
```

Folder and filename layout is human-facing and may evolve without changing identity. Stable UUIDs preserve relationships after renaming or moving files.

## Frontmatter

Example:

```yaml
---
chronicle_id: "0190f8da-460c-7f2c-9fd1-a86c21d95418"
type: experiment
project_id: "0190f8d2-3d30-7c90-bf21-32d69d2549fe"
status: draft
title: "ORF9b trajectory analysis"
tags: [orf9b, md]
created: 2026-07-13T15:20:00+03:00
updated: 2026-07-13T18:42:00+03:00
custom_field: "kept verbatim"
---
```

`chronicle_id` is mandatory for a managed note. Unknown frontmatter keys are retained through import and export. Chronicle-owned keys may be normalized, but unrelated keys must not be silently removed.

## Links

Chronicle supports stable ID links and readable title links:

```markdown
[[id:0190f8da-460c-7f2c-9fd1-a86c21d95418|ORF9b result]]
[[ORF9b result#Discussion]]
![[trajectory-rmsd.png]]
```

Resolution prefers encoded ID, then an unambiguous title/path. Ambiguity requires user choice rather than an arbitrary rewrite.

## Tasks

Ordinary Markdown checkboxes remain valid:

```markdown
- [ ] Repeat trajectory
- [x] Validate RMSD selection
```

A promoted Chronicle task may carry a readable stable annotation:

```markdown
- [ ] Repeat trajectory <!-- chronicle-task:0190f912-... -->
```

Extended task metadata remains in SQLite and portable exports; Chronicle does not inject verbose metadata into every Markdown line.

## Attachments

Managed attachments use collision-safe names and are indexed separately. The Markdown link remains portable and preserves the original readable filename where possible. Missing attachments are reported during Vault scan rather than silently removed from notes.

## Conflicts

Chronicle never silently overwrites divergent external edits. A conflict may create a preserved peer file such as:

```text
result.conflict-20260723-1842-lab-pc.md
```

The reconciliation UI shows both candidates and requires an explicit decision. A safety snapshot is created before applying reviewed changes.

## Indexes

`.chronicle/vault-index.json` maps stable note IDs to managed relative paths and content hashes. It is rebuildable metadata, not the only copy of note content. Deleting an index may require a review/rebuild, but must not delete Markdown notes.

## Portability

A complete portable export can include:

- Markdown Vault files;
- structured JSON/database snapshot;
- attachment manifest and files;
- CSV time entries;
- BibTeX library;
- format and application version metadata.

See [`75-v1-stability-contract.md`](75-v1-stability-contract.md) for compatibility guarantees and [`76-recovery-guide.md`](76-recovery-guide.md) for recovery procedures.
