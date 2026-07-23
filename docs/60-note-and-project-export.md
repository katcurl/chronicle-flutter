# Note and project export

Chronicle 0.26.4 adds explicit, read-only export for an open note and for a complete project. Export never rewrites the Vault, the database, synchronization state or the source notes.

## Formats

### Markdown

A note is saved as UTF-8 Markdown with Chronicle-compatible front matter. A project is saved as one readable Markdown document containing its description, task checklist and note contents. Ordinary Markdown export keeps existing Vault attachment links because it creates only one text file.

### Standalone HTML

Chronicle renders a self-contained HTML document with embedded CSS. Referenced images and other managed attachments are encoded as data URIs, so the HTML can be opened outside Chronicle without a neighbouring assets directory. Chronicle image width, alignment and caption metadata are rendered as figures.

### Portable ZIP

A note archive contains Markdown, HTML, `manifest.json` and only the managed attachments referenced by that note. A project archive contains `README.md`, `README.html`, separate Markdown and HTML files for every project note, a manifest and the shared referenced assets. Internal wiki links between project notes are converted to ordinary relative links.

The ZIP writer uses the standard uncompressed ZIP32 format and UTF-8 file names. Export is limited to 240 MB to keep the operation bounded in memory.

## Missing files

A missing attachment does not abort the whole export. Chronicle records the missing Vault path in the manifest and reports the count after saving. Existing readable content is still exported.

## Safety

Export uses the current unsaved editor text for an open note but does not save or mutate it. Project export uses the current persisted project data. No migrations or new database tables are introduced.
