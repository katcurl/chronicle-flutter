# Note columns

Chronicle 0.20 adds portable two- and three-column blocks to Markdown notes.

## Markdown representation

Columns are stored as ordinary Markdown separated by invisible HTML comments:

```markdown
<!-- chronicle-columns widths=40,60 -->
![Structure](../../Attachments/structure.png)
<!-- chronicle-column -->
The explanatory text is displayed to the right of the image.
<!-- /chronicle-columns -->
```

Outside Chronicle, applications that ignore the comments still show all column
contents in their original order. No binary or proprietary document format is
required.

## Editing

The columns toolbar action inserts a two- or three-column block. If text is
selected, Chronicle places it into the second column. Putting the cursor inside
an existing block and invoking the same action opens its layout settings.

In preview mode, dividers can be dragged to resize adjacent columns. Layout
changes are immediately persisted in the note Markdown. On narrow windows the
columns stack vertically to keep the content readable.

Images retain their own size, alignment and caption metadata inside a column.
The source attachment binary remains unchanged.

## Limits of the first implementation

Nested column blocks are intentionally unsupported. Column content is edited in
the Markdown editor and rendered visually in preview and split modes.
