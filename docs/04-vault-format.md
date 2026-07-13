# Vault format

## Goals

The Chronicle vault must remain understandable without Chronicle and usable by editors such as Obsidian, Sublime Text, Typora, or a plain text editor.

## Suggested structure

```text
Chronicle Vault/
  Workspaces/
    Research/
      Orf9b/
        project.md
        Notes/
        Work Items/
        Files/
    Teaching/
      Chemistry Course/
  Daily/
  References/
    library.bib
  Templates/
  Attachments/
  Archive/
  .chronicle/
    manifest.json
    operation-journal/
```

The folder layout is a user-facing default, not the identity model. Stable UUIDs preserve relationships after renaming or moving files.

## Frontmatter

Example:

```yaml
---
chronicle_id: "0190f8da-460c-7f2c-9fd1-a86c21d95418"
type: lecture
project_id: "0190f8d2-3d30-7c90-bf21-32d69d2549fe"
status: draft
title: "Lecture 1. Atomic structure"
tags:
  - chemistry
  - school
created: 2026-07-13T15:20:00+03:00
updated: 2026-07-13T18:42:00+03:00
---
```

`chronicle_id` is mandatory for files managed by Chronicle. Unknown frontmatter keys must be preserved.

## Links

Supported internal syntax:

```markdown
[[Lecture 2. Periodic law]]
[[Lecture 1. Atomic structure#Electron orbitals]]
![[orbital-diagram.png]]
```

Chronicle also supports ordinary relative Markdown links. Wiki-link resolution uses ID first when encoded, then exact path, then title with a disambiguation UI.

## Tasks in Markdown

Ordinary checkboxes remain valid Markdown:

```markdown
- [ ] Add orbital diagram
- [x] Check terminology
```

Promoted Chronicle tasks use a stable annotation that remains readable:

```markdown
- [ ] Add orbital diagram <!-- chronicle-task:0190f912-... -->
```

The application must not inject verbose metadata into every line. Extended task metadata lives in SQLite and is included in export manifests.

## Attachments

Default naming:

```text
Attachments/<content-hash-prefix>/<safe-original-name>
```

The content hash detects duplicates. The UI preserves and displays the original filename.

## Conflict files

Chronicle never silently overwrites divergent external edits. A conflict creates:

```text
filename.conflict-20260713-1842-device.md
```

and opens a comparison flow.

## Portability export

A complete export includes:

- vault files;
- SQLite database snapshot;
- JSON manifest;
- CSV time entries;
- BibTeX library;
- human-readable migration/version metadata.
