# Chronicle v0.10 — Projects & Tasks

This release turns projects and tasks into editable domain objects instead of demo cards.

## Database migration v2

Projects gain color, deadline and time-budget fields. Tasks gain description, priority,
parent task and stable sort order. Existing rows receive safe defaults and remain readable.

## Project workflow

- Create and edit projects.
- Choose emoji and calm accent color.
- Set a deadline and optional time budget.
- Archive and restore projects.
- Open a project dashboard with progress, notes, tracked time and tasks.

## Task workflow

- Create and edit tasks.
- Set status, priority, estimate, deadline and description.
- Create one level of subtasks.
- Search and filter by project and priority.
- Start a timer directly from a task.
- Soft-delete tasks without breaking old time entries.

The release intentionally keeps Markdown and synchronization separate. Their data model can
now safely reference stable project and task identifiers.
