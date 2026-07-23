# Interactive knowledge graph

Chronicle 0.26.7 expands the existing read-only knowledge map into an
interactive graph exploration workspace. It continues to use the current
`NoteLink` index and does not introduce a new database table or Vault format.

## Filters

The graph can be narrowed by project, note type and tag. The **Connected only**
filter hides isolated notes without deleting or changing them. Search remains a
visual highlight rather than a destructive filter, which makes it possible to
see where a matching note sits inside the surrounding structure.

## Selection and local focus

Selecting a node opens a side card with:

- its project, type and folder;
- incoming and outgoing link counts;
- all directly connected notes;
- an explicit action for opening the note.

A selected note can be shown with its one-step or two-step neighborhood. Focus
mode traverses links as an undirected neighborhood so both references and
backlinks remain visible. It intentionally overrides project/type/tag filters
until focus mode is closed.

## Direction and graph structure

Optional arrowheads show the stored direction of each link. Hovering or
selecting a node emphasizes every edge that touches it and dims unrelated
nodes.

The graph-structure dialog reports:

- connected components;
- resolved and unresolved links;
- isolated notes;
- the notes with the highest total incoming and outgoing degree.

Graph analysis is deterministic, deduplicates repeated links and ignores
self-links. Neighborhood traversal is bounded to four steps internally; the UI
exposes one and two steps to keep the map readable.

## Compatibility and safety

- No database migration.
- No automatic edits to notes or links.
- No background graph scan while typing in the Markdown editor.
- Existing title links and stable `[[id:...|Title]]` links continue to use the
  same resolved note-link index.
- Vault layout, synchronization and export formats are unchanged.
