---
name: Foundations and title wiring
overview: Create simple foundation files for typography, spacing, and colors, then wire them into key screens (especially TitleView, TaskListView, and TaskEditorSheet) with larger title text and improved spacing using light/dark-safe asset colors.
todos:
  - id: foundations-typography
    content: Implement simple system-font typography tokens in Design/Foundations/Typography.swift
    status: completed
  - id: foundations-spacing
    content: Implement spacing tokens in Design/Foundations/Spacing.swift and add commonly used layout constants
    status: in_progress
  - id: foundations-colors
    content: Add Design/Foundations/Colors.swift with semantic aliases mapped to asset color names
    status: pending
  - id: titleview-restyle
    content: Refactor Design/Navigation/TitleView.swift to use new typography/spacing/colors with larger title text
    status: pending
  - id: wire-tasklist-editor
    content: Apply typography/spacing/color tokens to TaskListView and TaskEditorSheet paddings/title usage
    status: pending
  - id: wire-row-toggle-colors
    content: Start wiring semantic colors/fonts in TaskRow and TaskStateToggle
    status: pending
  - id: validate-lints-and-ui
    content: Run lints/build and verify light/dark visual consistency and no behavior regressions
    status: pending
isProject: false
---

# Add Design Foundations and Wire Core Screens

## Scope

Implement a lightweight design foundation (no theme environment) and start applying it in the most visible places:
- custom fonts/sizes (system-based tokens)
- spacing tokens (especially paddings)
- semantic color tokens using existing asset colors (light/dark aware)

Primary focus: `TitleView`, `TaskListView`, and `TaskEditorSheet`.

## Files to add/update

- Add and fill [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Design/Foundations/Typography.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Design/Foundations/Typography.swift)
- Add and fill [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Design/Foundations/Spacing.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Design/Foundations/Spacing.swift)
- Add new [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Design/Foundations/Colors.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Design/Foundations/Colors.swift)
- Update [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Design/Navigation/TitleView.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Design/Navigation/TitleView.swift)
- Update [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift)
- Update [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/Editor/TaskEditorSheet.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/Editor/TaskEditorSheet.swift)
- Start applying to list row visuals in [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskRow.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskRow.swift) and [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskStateToggle.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskStateToggle.swift)

## Foundation design (simple/direct)

1. **Typography tokens** in `Typography.swift`
- Use system fonts directly (no custom font bundle dependency).
- Define clear static tokens (e.g. screen title, section title, body, caption, chip, button).
- Make `TitleView` use a larger title token than current `.title2`.

2. **Spacing tokens** in `Spacing.swift`
- Define static spacing values used throughout views (screen horizontal, section vertical, control heights, chip height, list gap, etc.).
- Replace ad-hoc literals first in TitleView + TaskListView + TaskEditorSheet.

3. **Color tokens** in `Colors.swift`
- Map asset palette names to semantic `Color` aliases:
  - `PrimaryTextColor`
  - `SecondaryTextColor`
  - `SuccessColor`
  - `WarningColor`
  - `ErrorColor`
  - (optionally background/surface aliases based on system colors)
- Use these aliases so colors auto-adapt in light/dark mode via asset catalog.

## Wiring strategy

1. **TitleView first (priority)**
- Increase title font size/weight via typography token.
- Increase and normalize top/horizontal/bottom spacing via spacing tokens.
- Apply semantic text/background colors from color tokens.

2. **TaskListView and TaskEditorSheet**
- Replace hard-coded paddings/heights with spacing tokens.
- Keep behavior unchanged; only style system and layout rhythm updates.
- Ensure custom title in both places reflects larger typography and improved spacing.

3. **Initial row/state color application**
- In `TaskRow`, use primary/secondary text color tokens.
- In `TaskStateToggle`, replace hard-coded `.blue/.yellow/.red` with semantic success/warning/error tokens.

## Validation

- Run lints on all changed files.
- Build check (if local Xcode environment available).
- Manual UI spot checks:
  - title readability and spacing in `TaskListView`
  - title/readability and control spacing in `TaskEditorSheet`
  - colors match palette in both light and dark modes
  - no behavior regression for toggles, save/dismiss, drag/drop
