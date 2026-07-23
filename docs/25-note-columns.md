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

The columns toolbar action opens a visual two- or three-column composer. If text
is selected, Chronicle places it into the second column before the composer
opens. Each column body can then be edited separately as Markdown without
manually touching Chronicle's marker comments. Putting the cursor inside an
existing block opens the same composer with all current column contents.

Chronicle 0.24.8 adds one-click layouts for a figure on the left with explanatory
text on the right, the mirrored text-and-figure arrangement, two equal columns
and three equal columns.

In preview mode, dividers can be dragged to resize adjacent columns. Layout
changes are immediately persisted in the note Markdown. On narrow windows the
columns stack vertically to keep the content readable.

Images retain their own size, alignment and caption metadata inside a column.
The source attachment binary remains unchanged.

## Limits

Nested column blocks are intentionally unsupported. Column bodies remain
ordinary Markdown and are rendered visually in preview and split modes.
