# Note column management

Chronicle 0.20.1 extends the portable Markdown column blocks introduced in
0.20.0 without changing the storage format.

From the column control in preview, a user can:

- move existing column content left or right;
- switch between two and three columns;
- change width presets or use sliders;
- convert the block back to ordinary Markdown while retaining all content.

Reordering changes only the order of the column bodies. Images, captions,
formulas, lists and wiki links remain represented by their original Markdown.
When a three-column block becomes two columns, the last remaining body is
appended to the second column with a blank line. When a two-column block
becomes three columns, Chronicle creates a new placeholder column.

Removing the column layout strips only Chronicle's HTML comment markers and
joins the column bodies with blank lines, so the note remains readable and
portable.

## Visual composer in 0.24.8

The same management dialog now exposes a separate Markdown editor for every
column. Users can change text, images, captions, lists, tables and formulas in
place, move a complete body left or right, select a quick layout and change
widths before applying the result.

Reducing a three-column composition to two columns merges the third body into
the second with a blank line. Expanding to three columns adds a visible
placeholder and never discards either existing body. Converting the block back
to ordinary text uses the edited bodies shown in the composer.
