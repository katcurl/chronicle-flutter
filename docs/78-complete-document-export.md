# Chronicle 1.0.4: complete DOCX and PDF export

DOCX and PDF use one local GitHub-Flavored Markdown parser and one attachment-loading contract. No cloud conversion service is involved.

The exporter renders headings, paragraphs, bold and italic text, strike-through, inline and fenced code, links, block quotes, ordered and unordered lists, task checkboxes, Markdown tables, horizontal rules and images. Source text is retained even when an attachment is unavailable.

Managed image targets are resolved through `AppStore.readManagedAttachment`. PNG, JPEG, GIF, WebP, SVG and BMP data can be embedded in the generated document. Chronicle width, alignment and caption metadata are preserved where the destination format supports them. Base64 `data:image/...` sources are also handled locally.

An unreadable, missing or unsupported image is represented by a visible placeholder and returned in `ChronicleExportPayload.missingAttachments`; it is never silently dropped. Remote image URLs are not fetched during export.

DOCX stores images in the package media folder and remains editable in Word or LibreOffice. PDF uses a local Unicode font, embeds resolved images and includes page numbering.
