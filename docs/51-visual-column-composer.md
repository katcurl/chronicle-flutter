# Visual column composer

Chronicle 0.24.8 makes the existing portable column syntax usable without
editing its HTML comment markers by hand.

## Creating a composition

Use **Вставить или настроить колонки** in the note editor. The dialog offers
these quick layouts:

- figure or image on the left and explanatory text on the right (40/60);
- text on the left and a figure on the right (60/40);
- two equal columns;
- three equal columns.

Selected Markdown is placed into the second column before the dialog opens. If
the selection begins with a Markdown image, Chronicle places that image in the
first column and the remaining selected text in the second. Every column has
its own Markdown field, so an image with its caption can stay together while
the interpretation is written beside it.

## Editing an existing block

Place the cursor anywhere inside a column block and invoke the same command, or
use the column control in preview. Chronicle loads the existing bodies into the
visual composer. Arrow buttons move a complete body without rewriting its
Markdown. Width presets and sliders remain available.

Switching from three columns to two merges the last two bodies with a blank
line. Switching from two to three adds a new placeholder body. The operation
does not alter attachment binaries, image presentation metadata, captions,
scientific identifiers, Vault paths or synchronization state.

## Storage and compatibility

The on-disk representation is unchanged:

```markdown
<!-- chronicle-columns widths=40,60 -->
![Structure](../../Attachments/structure.png)
<!-- chronicle-column -->
The explanatory text is displayed to the right.
<!-- /chronicle-columns -->
```

Other Markdown applications continue to show the bodies in reading order even
when they ignore Chronicle's comments. Existing notes require no migration.
