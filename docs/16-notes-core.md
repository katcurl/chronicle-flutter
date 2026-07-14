# Chronicle v0.11 — Notes Core

This release turns notes into a first-class local-first knowledge layer.

## Included

- Structured note metadata stored in Drift and mirrored in YAML front matter.
- Note types, statuses, folders, tags, pinning and custom properties.
- Built-in templates for lectures, research journals, literature notes and meetings.
- GitHub-flavoured Markdown rendering through `flutter_markdown_plus`.
- Inline and display LaTeX rendering.
- Wiki links, outgoing links and backlinks.
- Linked tasks and per-note time tracking.
- Manual note snapshots with restore support.
- Responsive editor, preview and desktop split view.
- Markdown images from HTTPS and data URLs.
- Database migration from schema v2 to v3 without deleting existing notes.

## Deliberately deferred

Filesystem-backed vaults and copied local attachments belong to the next vault release.
The v0.11 renderer already understands image Markdown and keeps notes portable.
