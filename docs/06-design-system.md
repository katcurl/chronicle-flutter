# Design system

## Design intent

Chronicle should feel calm, precise, and warm. The interface supports sustained concentration and avoids visual competition with user content.

## Visual principles

- content before chrome;
- restrained use of accent color;
- generous spacing without wasting small screens;
- no decorative gradients in routine work surfaces;
- borders only when they clarify grouping;
- motion communicates causality, not decoration;
- dense metadata appears in secondary panels and sheets.

## Color tokens

Use semantic tokens rather than hard-coded colors:

- `surface`
- `surfaceContainer`
- `surfaceContainerHigh`
- `onSurface`
- `onSurfaceVariant`
- `primary`
- `onPrimary`
- `secondary`
- `error`
- `warning`
- `success`
- `outline`

Project colors are accents, not full-card backgrounds.

## Typography

- Display: rare, dashboard-level metrics only.
- Headline: screen and project titles.
- Title: cards and sections.
- Body: notes and explanatory content.
- Label: controls and metadata.
- Monospace: Markdown source, code, identifiers, and time values where alignment matters.

Respect Android font scaling up to at least 200% without clipping critical controls.

## Spacing scale

```text
4, 8, 12, 16, 24, 32, 48
```

Default page horizontal padding:

- compact handset: 16
- large handset/tablet: 24
- desktop content column: 32

## Shape

- small controls: 8
- cards and sheets: 16
- prominent timer surface: 24
- pills only for tags, compact filters, and statuses

## Core components

### Active timer bar

Always accessible while running. Shows elapsed time, current work item, project, pause, and stop. It must not obscure bottom navigation.

### Work item card

Shows title, project, status, next action, estimate versus actual, and recent output. Secondary data expands on demand.

### Note editor

A distraction-reduced canvas. Properties and backlinks open in a side panel or bottom sheet rather than permanently narrowing the editor on phones.

### Empty state

Explains the benefit of the screen and gives one clear action. Avoid generic illustrations that consume space.

## Navigation

Phone primary destinations:

1. Today
2. Projects
3. Notes
4. Tasks
5. More

A running timer is a persistent contextual element, not a sixth navigation destination.

Tablet/desktop uses a navigation rail or sidebar and supports split views.

## Reduced cognitive load

- one primary action per screen;
- no red badges for ordinary overdue personal tasks;
- timers do not flash;
- avoid gamified streak loss;
- provide a focus mode that hides counts and secondary navigation;
- preserve scroll and editing position when switching context.
