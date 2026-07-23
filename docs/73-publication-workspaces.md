# Publication and report workspaces

Chronicle 0.31.0 introduces the first document-assembly layer for research
projects. It does not replace the note editor, Word or LaTeX. Instead, it turns
existing project notes into a structured output while keeping the analysis in
its original place.

## Storage model

A publication workspace is stored as an ordinary `Note` with
`noteType: publication`. The editable structure is encoded in the existing
string properties map, so no database migration or new Vault entity is needed.
The note body remains readable and contains stable wiki links to every source
note. Backups, synchronization, history, Vault mirroring and soft deletion use
the existing note pipeline.
Publication notes remain visible in Chronicle's general note overview and knowledge graph, but opening one routes back to the dedicated assembly workspace so its structural metadata cannot be accidentally edited as ordinary Markdown.

## Live fragments

Each document section can contain its own connecting text plus references to:

- an entire project note;
- the content beneath one Markdown heading in a project note.

The workspace stores only the source note ID and heading title. Preview and
export resolve the current source text on demand. If a source note is deleted or
a heading is renamed, Chronicle reports the broken fragment instead of silently
keeping a stale copy.

## Templates and assembly

Built-in structures are available for a scientific article, a research or
practice report, and a presentation outline. Sections and live fragments can be
added, removed and reordered without imposing a laboratory workflow.

The assembled document can optionally:

- number Chronicle figures and Markdown tables across all included fragments;
- recognize definitions written as `full term (ABC)` and append an abbreviation
  list;
- resolve existing `[@citation-key]` references and append the bibliography;
- preserve Chronicle image metadata and used attachments during export.

The workspace shows word, fragment, figure, table and abbreviation counts and
opens a complete Markdown preview before export.

## Export

The assembled result reuses Chronicle's existing safe export pipeline and can
be saved as Markdown, autonomous HTML or a portable ZIP with referenced assets.
Export never rewrites the source notes or the saved publication workspace.

DOCX, PDF and LaTeX outputs, a dedicated figure/table manager and caption checks
remain later 0.31 milestones.
