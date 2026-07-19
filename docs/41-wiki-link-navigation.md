# Wiki-link navigation and backlinks

Chronicle 0.23.2 extends the existing portable `[[wiki link]]` format without
changing the database schema or rewriting stored notes.

## Editing

Typing `[[` in the Markdown editor opens a small suggestion strip. The strip
listens directly to the text controller and does not rebuild the complete note
workspace. Selecting a suggestion inserts the closing brackets automatically.

Aliases remain supported:

```text
[[TM-score|сравнение структур]]
```

When the same title exists in several projects, Chronicle can store a readable
qualified target:

```text
[[Orf9b research :: RMSD]]
```

The preview shows only `RMSD` unless an explicit alias is present.

## Resolution rules

For an unqualified title Chronicle resolves, in order:

1. one exact global match;
2. one match in the source note's project and folder;
3. one match in the source note's project.

An ambiguous target is never attached to the first matching note. Opening it
shows a chooser. Qualified targets are matched against the project title.

## Context panel

Backlinks include a short excerpt around the source link. Outgoing links show
the target project and folder. Missing targets have an explicit Create action.

## Safety

The knowledge map now draws only links with a resolved target ID. Ambiguous and
missing links remain visible in the unresolved count. The feature does not
rename notes, rewrite existing Markdown, migrate the database, or change Vault
and LAN synchronization behavior.
