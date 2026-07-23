# Chronicle 0.30 — wallpapers, glass and sparkles

Chronicle 0.30 extends the local appearance system without changing research data.

## Global wallpaper

The Appearance dialog accepts PNG, JPEG, WebP and animated GIF files up to 30 MB. Chronicle validates the file signature and copies the selected file into its application-support directory. The original download can then be moved or deleted safely.

Wallpaper brightness and a palette-colored overlay are controlled independently. The configured background color remains behind the image and is used automatically when the managed file is missing or cannot be decoded.

## Glass surfaces

Panel opacity can be reduced from 100% to 35%. Backdrop blur is available whenever panels are translucent. Matte, Glossy and Shiny keep their existing geometry while using the selected opacity and blur.

Shiny also has an independent sparkle intensity from 0% to 200%. Sparkles are deterministic, non-interactive and static; no perpetual animation is introduced.

## Project wallpapers

A project that does not inherit the global appearance can use a separate managed wallpaper and its own wallpaper brightness, overlay, panel opacity, blur and sparkle intensity. The appearance is scoped to project cards, project details and note workspaces belonging to that project.

Global and project background metadata stays in SharedPreferences. Files live in managed application-support directories. The database, Markdown, Vault structure, attachments and synchronization payloads are unchanged.
