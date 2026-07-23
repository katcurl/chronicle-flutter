# Chronicle 1.0.3: public-release polish

## Empty-by-default workspace

A repository that has already been initialized is loaded exactly as before. A new installation with no initialized repository starts from `AppData.empty()` and therefore contains no projects, notes, tasks, time entries, citation sources or seeded examples.

The application retains the blank internal note definition needed to create a note, but bundled scientific and laboratory templates are not exposed as working choices. The project screen opens the ordinary blank project editor. Personal templates remain opt-in: users may create, import, edit and delete their own templates later.

This change is deliberately not a migration. Updating Chronicle never clears an existing database, Vault or custom-template store.

## Today screen

The onboarding phrase “Готова начать?” was removed. An empty installation shows a neutral empty-workspace state, and focus timing remains unavailable until the user creates a project. Existing projects and tasks continue to populate the same dashboard sections.

## Regression coverage

The release tests verify that a new installation is empty, exposes no bundled working templates and does not render the removed onboarding phrase.
