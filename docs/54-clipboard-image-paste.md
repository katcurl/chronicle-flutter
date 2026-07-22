# Clipboard image paste

Chronicle 0.25.0 adds direct clipboard-image insertion to the Markdown note editor on Windows.

## User flow

- Press `Ctrl+V` while the Markdown editor is focused.
- If the Windows clipboard contains image data or a copied image file, Chronicle reads it as PNG, stores it in the current Vault and inserts a Markdown image reference at the cursor.
- If there is no image, Chronicle falls back to ordinary plain-text paste.
- The editor toolbar also exposes **Вставить изображение из буфера** for an explicit image-only action.

## Storage and safety

Pasted bytes pass through the same attachment service as files selected from disk. Therefore they use content hashing, deduplication, `Attachments/`, `.chronicle/attachments-index.json`, backup inclusion and LAN attachment synchronization. Existing notes and attachments are not rewritten.

The Windows clipboard is read asynchronously in an STA PowerShell process. Native DIB/DIBv5 images and copied image files are serialized to PNG in memory. Chronicle does not modify the clipboard and does not create an unmanaged temporary image file.

On platforms without the Windows image reader, `Ctrl+V` continues to paste text and the explicit image action reports that no image is available.
