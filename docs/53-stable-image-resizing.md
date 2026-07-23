# Stable image resizing

Chronicle 0.24.10 removes the visible jump and unnecessary attachment work that
could occur when changing a managed image width in preview or split mode.

## Stable interaction

While the drag handle is moving, pointer deltas are coalesced to one layout
update per rendered frame. This prevents a high-frequency mouse stream from
requesting more image layouts than Flutter can display.

When the drag ends or a preset is selected, the requested percentage remains
visible until the updated Markdown reaches the preview. The image therefore no
longer briefly returns to its previous width between the local gesture and the
Markdown rebuild.

Image-size changes update the open preview immediately and mark the note as
dirty. They use the same explicit save paths as ordinary text edits instead of
forcing a complete AppStore save for each drag operation.

## Attachment refresh isolation

The note preview previously listened to every AppStore notification as though
it represented a changed attachment. Saving an image width could consequently
make all Vault images in the open note read their binary files again.

Chronicle now exposes a dedicated attachment refresh signal. It changes only
when attachment files may actually have changed, including attachment import,
LAN synchronization, Vault application and backup restoration. Ordinary note,
project, task and timer updates do not reload image binaries.

## Compatibility

Image width remains stored in the existing portable Markdown title metadata:

```markdown
![Orf9b](../../Attachments/orf9b.png "chronicle-image width=50 align=center")
```

No attachment is resized, recompressed, renamed or moved. The database schema,
Vault layout, synchronization payloads, themes and existing notes require no
migration.
