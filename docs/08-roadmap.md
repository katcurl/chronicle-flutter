# Roadmap to v1.0

Each milestone must end with a buildable APK, migration tests, and a tagged release.

## v0.1 Foundation

Deliverables:

- product specification;
- domain model;
- architecture decisions;
- vault and database schema;
- design system;
- roadmap and definition of done.

Exit criterion: documents reviewed and committed to the repository.

## v0.2 App shell

- reliable Flutter project scaffold;
- Material 3 theme and tokens;
- adaptive phone/tablet navigation;
- error boundary and logging;
- CI: format, analyze, test, APK artifact.

Exit criterion: empty app shell installs and runs on a physical Android device.

## v0.3 Persistence core

- Drift/SQLite database;
- schema migrations;
- repository interfaces;
- workspaces, projects, and settings;
- backup of structured data.

Exit criterion: projects survive process death and application upgrades.

## v0.4 Time tracking

- timer state machine;
- foreground service and notification;
- manual records;
- recovery after process termination;
- daily session list.

Exit criterion: a 2-hour timer remains correct through screen lock and app restart.

## v0.5 Work management

- work items;
- tasks, subtasks, statuses, dependencies;
- estimates and actual time;
- Today and project views.

Exit criterion: user can plan, execute, and close a work item end to end.

## v0.6 Notes core

- Markdown files in vault;
- source editor and preview;
- LaTeX, images, tables, checklists;
- frontmatter preservation;
- file watcher and reconciliation.

Exit criterion: notes remain editable in both Chronicle and Obsidian without data loss.

## v0.7 Knowledge links

- wiki-links;
- backlinks;
- headings and block links;
- full-text search;
- local graph and saved views.

Exit criterion: renames and file moves retain valid relationships.

## v0.8 History and research tools

- project event timeline;
- note version history;
- BibTeX and citations;
- experiment and literature templates;
- outcome journal.

Exit criterion: a research project can produce a traceable weekly report.

## v0.9 Portability and polish

- complete import/export;
- backup restore UI;
- accessibility audit;
- performance profiling;
- onboarding;
- crash recovery and diagnostics.

Exit criterion: beta users can migrate in and out without developer assistance.

## v1.0 Stable Android release

- signed APK/AAB;
- documented privacy behavior;
- migration guarantees;
- user documentation;
- reproducible release pipeline;
- no known data-loss bugs.

## After v1.0

- desktop applications;
- optional encrypted sync;
- calendar integration;
- Android widgets;
- controlled AI assistance;
- plugin API only after core formats stabilize.
