# Flutter 3.44 reorder callback migration

Chronicle 0.22.3 updates the isolated block-order dialog to Flutter 3.44's
`onReorderItem` callback.

The old `onReorder` callback supplied an unadjusted destination index when an
item moved downward, so Chronicle manually subtracted one before inserting the
removed item. Flutter 3.44 deprecates that callback. `onReorderItem` now supplies
the already-adjusted index, therefore the manual subtraction must be removed.

This is a build-compatibility migration only. It does not alter the Markdown
block model, the confirmation-before-apply workflow, undo handling, note data,
Vault storage, synchronization, theme, or palette.
