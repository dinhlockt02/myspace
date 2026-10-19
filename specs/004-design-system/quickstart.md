# Quickstart: Validate the Design System

**Feature**: `004-design-system`

Runnable scenarios that prove the feature end to end. Interfaces are in [contracts/](contracts/); entities in [data-model.md](data-model.md). Commands assume the repository root and the project/target names the plan defines (`ui` for `packages/ui`, `idea-collector-frontend` for the app).

## Prerequisites

- Node 22 or newer and pnpm; run `pnpm install` after the package exists
- Playwright's Chromium browser: `pnpm exec playwright install chromium`
- A feature branch (not `main`)
- Implementation complete (`/speckit-implement`)

## Scenario 1: Tokens meet WCAG AA (User Story 1, FR-001, FR-005)

```bash
pnpm nx run ui:test -- --project unit
```

Expected: `tokens.contrast.test.ts` passes. Every one of the 26 pairs in [contracts/design-tokens.md](contracts/design-tokens.md) meets its threshold in both modes, and every color token has a light and a dark value.

## Scenario 2: Catalog shows every component, state and theme (FR-010)

```bash
pnpm nx run ui:storybook
```

Expected: the catalog opens; every component from FR-014 and the three layout primitives has stories for each variant and state; the toolbar switches light and dark and the story re-themes without a flash.

## Scenario 3: Automated accessibility gate in both themes (SC-002, FR-015)

```bash
STORYBOOK_THEME=light pnpm nx run ui:test -- --project storybook
STORYBOOK_THEME=dark  pnpm nx run ui:test -- --project storybook
pnpm nx run ui:test -- --project browser    # real-browser tests: coexistence and responsive overflow
```

Expected: all three runs pass with zero axe violations across every story. To prove the gate works, temporarily lower a token below its pair threshold or remove an `aria-label` from an icon button story: the run must fail naming the story and the rule.

## Scenario 4: Keyboard operability (User Story 4, FR-006)

Run as part of Scenario 3 (the `play` tests). Then verify by hand in the catalog: using only Tab, Shift+Tab, Enter, Space, Escape and the arrow keys, reach and operate Button, Input, Textarea, Select, Checkbox, RadioGroup, Tooltip and Dialog. Expected: every control shows a visible focus ring in a logical order; a dismissible Dialog traps focus and closes on Escape, its close button and a backdrop click; focus returns to the trigger.

## Scenario 5: Theme switching and persistence (User Story 3, FR-004, SC-003)

1. Start the migrated app (`pnpm nx run idea-collector-frontend:dev`) with the OS in dark mode and local storage cleared. Expected: the first paint is dark, with no light flash.
2. In the browser console run `localStorage.setItem('ui-theme','light')` and reload. Expected: light, overriding the OS.
3. Toggle the theme repeatedly through `useTheme` (or the catalog toolbar). Expected: no flicker, no partially themed elements, and each switch finishes within 100 ms (check the Performance panel).

## Scenario 6: Responsive layout without overflow (User Story 4, FR-007, SC-004)

Run `pnpm nx run ui:test -- --project browser` (the responsive overflow test, part of Scenario 3). Then by hand, resize the app and the layout stories from 320px to 2560px. Expected: no horizontal scrollbar at 320, 375, 640, 1024 or 2560 px; `AppHeader` actions wrap under the brand below 640px; `SidebarLayout` stacks below 1024px; a very long label wraps or truncates with a tooltip instead of overflowing.

## Scenario 7: The migrated app behaves exactly as before (FR-013, User Story 2 scenario 4)

```bash
pnpm nx run idea-collector-frontend:test
```

Expected: the characterization tests, written before the migration and unchanged since, all pass: sign-in action, idea form validation and submission, list states, header sign-out, and the non-dismissible session-expired dialog.

Then by hand against a dev build: sign in, submit an idea, see it listed, and let the session expire (or force it). Expected: the same flows and copy as before, with the new theme.

## Scenario 8: Migration is complete and nothing leaks (FR-009, FR-013, SC-001)

```bash
test ! -e apps/idea-collector/frontend/src/App.css && echo "App.css removed"
grep -rnE "#[0-9a-fA-F]{3,8}\b|rgb\(|hsl\(" apps/idea-collector/frontend/src --include=*.tsx --include=*.css | grep -v "GoogleIcon" || echo "no raw colors"
grep -rnE "^\s*(body|html|h[1-6]|a|button|input|\*)\s*[,{]" packages/ui/src/styles || echo "no element selectors in theme.css"
```

Expected: `App.css` is gone, no raw color literals remain in the app (the Google logo's brand colors live in `GoogleIcon`), and `theme.css` contains no element selectors.

## Scenario 9: Coexistence with an un-migrated view (edge case, FR-009)

Automated by `packages/ui/src/styles/theme-coexistence.browser.test.tsx` (the `browser` project in Scenario 3): plain unstyled HTML keeps identical computed styles when `theme.css`, and the layered consumer stylesheet without the base reset, are added. By hand, you can confirm the same in a scratch page. Expected: the plain HTML renders exactly as it did before the import.

## Scenario 10: Lint, types and build (constitution Principle III)

```bash
pnpm nx run-many -t lint,typecheck,test,build -p ui idea-collector-frontend
pnpm nx run ui:build-storybook
```

Expected: all pass. Building the static catalog in CI is the gated workflow task (research D12).

## Automated summary

| Check | Where | Covers |
| :--- | :--- | :--- |
| Token contrast, both modes | `ui:test` unit project | FR-005 |
| Axe over every story, both themes | `ui:test` storybook project | SC-002, FR-015 |
| Keyboard `play` tests | `ui:test` storybook project | FR-006 |
| Responsive overflow | `ui:test` browser project | FR-007, SC-004 |
| No change to unstyled HTML (coexistence) | `ui:test` browser project | FR-009 |
| Characterization tests | `idea-collector-frontend:test` | FR-013 |
