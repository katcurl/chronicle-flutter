# Responsive note images

Chronicle 0.19.3 keeps image binaries in `Attachments/` unchanged and stores
only presentation settings in the Markdown note.

A configured image remains valid Markdown:

```markdown
![Orf9b](../../Attachments/orf9b.png "chronicle-image width=55 align=right caption=MD-generated%20state")
```

The quoted title contains Chronicle-specific display metadata:

- `width` is a responsive percentage from 20 to 100;
- `align` is `left`, `center` or `right`;
- `caption` is optional URI-encoded text.

Markdown readers that do not understand the metadata can still render the
image normally. Chronicle renders the selected width and alignment, shows the
caption below the image and allows the width to be changed with a drag handle
in preview mode.

Existing Markdown images without Chronicle metadata remain compatible and are
shown at 100% width, centered. Their display settings can be added later from
the editor toolbar or by clicking the image in preview mode.
