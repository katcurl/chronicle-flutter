# Quick image sizing

Chronicle 0.24.7 makes the existing responsive image controls easier to find
and use without introducing a second image format.

## Preview controls

Hovering a managed image in preview or split mode reveals its current width as
a percentage. The percentage opens a compact menu with:

- responsive presets at 25%, 50%, 75% and 100%;
- a 5% decrease action;
- a 5% increase action;
- the existing detailed image-settings action beside it.

The drag handle in the lower-right corner remains available for continuous
mouse resizing. Drag results are rounded to the same 5% step before being
saved.

## Safe persistence

Only the `width` value in Chronicle's quoted Markdown image title is changed:

```markdown
![Orf9b](../../Attachments/orf9b.png "chronicle-image width=50 align=center")
```

The attachment binary is never resized, recompressed, renamed or moved. Image
aspect ratio remains controlled by Flutter's image widget, and old Markdown
images without Chronicle metadata still render at 100% width.

The **Сбросить размер** command in the detailed dialog restores 100% width but
preserves alignment, caption text and a scientific figure ID.

No database migration is involved. Vault structure, attachment synchronization,
visual themes and existing note text remain unchanged unless the user selects a
new size for a specific image.
