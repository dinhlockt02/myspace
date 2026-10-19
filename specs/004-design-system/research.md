# Research: Consistent Design System and Shared UI Library

**Feature**: `004-design-system` | **Date**: 2026-10-19

The spec has no `NEEDS CLARIFICATION` markers. This document records the technical decisions the plan depends on and, more importantly, the places where the spec as written conflicts with reality in this repository. Versions were checked against the npm registry on 2026-10-19.

## Spec tensions found (read these first)

| # | Tension | Resolution |
| :--- | :--- | :--- |
| T1 | User Story 2 scenario 3 says every dialog dismisses with Escape, the close icon and a backdrop click. The existing session-expired dialog is deliberately non-dismissible (no close control; the user must sign in again). FR-013 says behavior is preserved. | The `Dialog` has a `dismissible` option (default `true`). The session-expired dialog sets it to `false`. **Spec amended**: scenario 3 now applies to dismissible dialogs, new scenario 6 covers the non-dismissible case, and new FR-016 states the rule. |
| T2 | FR-005 requires WCAG 2.1 AA for every token combination. The stock shadcn neutral theme uses a very light border for inputs (about 1.3:1 against white), but WCAG 1.4.11 needs 3:1 for the boundary of a form control. | Keep the stock theme but make `--input` (control boundary) and `--ring` meet 3:1 in both modes. `--border` stays decorative. See D7. |
| T3 | FR-001 says "shared Tailwind preset". Tailwind v4 (current) has no JavaScript presets; the equivalent is a shared CSS theme file. | The preset is realized as `@myspace/ui/theme.css`. See D2. |
| T4 | FR-012 says standardize on Lucide icons. Lucide 1.x ships no brand logos, and the app's Google sign-in button needs the Google logo (duplicated inline SVG today). | Lucide for every interface icon; the Google logo is a single brand asset component. See D5. |
| T5 | The existing app's `App.css` defines `--primary`, `--danger`, `--radius-sm/md/lg`, `--font-sans` and others. These collide with the shadcn token names and would silently restyle the new components. | Migration step 0 renames the legacy variables with a `--legacy-` prefix; `App.css` is deleted at the end. See D13. |
| T6 | FR-006 (keyboard operability) cannot be proven by axe alone. | Every interactive component story has a keyboard `play` test run by the same Storybook/Vitest setup. See D10. |
| T7 | FR-011 requires `SidebarLayout`, but no existing idea-collector screen uses a sidebar. | Built and covered by stories and the responsive test only; no migration consumer. |
| T8 | SC-005 ("30% faster to build views") has no baseline and cannot be measured. | Not verified by this feature. Recorded as an outcome metric, not a buildable requirement. |

## D1. Package location, name and consumption

- **Decision**: `packages/ui`, published inside the workspace as `@myspace/ui`, consumed **from source**: `package.json` `exports` point at `src/*.ts(x)` and `src/styles/theme.css`. Add `packages/*` to `pnpm-workspace.yaml` and the new path to the root `package.json` `workspaces` list so the two stay in sync. Applications depend on it with `"@myspace/ui": "workspace:*"`.
- **Rationale**: The constitution designates `packages/` for shared libraries. Source consumption means a component edit shows up in the app with no build, which keeps the migration tight. Vite already transpiles TypeScript, and Nx derives the dependency graph from `workspace:*`, so `idea-collector-frontend` is rebuilt by the existing pipeline whenever `packages/ui` changes.
- **Alternatives considered**: A prebuilt `dist` (rejected: adds a build step and a staleness failure mode with no consumer outside the monorepo); `shared/ui` (rejected: `packages/` is listed first in the repo conventions); a package per component (rejected: far more structure than 12 components need).

## D2. Tailwind version and the shared preset

- **Decision**: Tailwind CSS 4.3 with `@tailwindcss/vite`. The shared "preset" is `packages/ui/src/styles/theme.css`: the token variables under `:root` and `.dark`, an `@theme inline` block mapping them to Tailwind color/radius utilities, the dark variant declaration, and `@import "tw-animate-css"`. It does **not** include Tailwind's base reset (see D13).
- **Rationale**: v4 is current and the shadcn component patterns are written for it. A CSS file is the v4 equivalent of a preset and works for any app that imports it.
- **Alternatives considered**: Tailwind 3.4 with a JavaScript preset (rejected: legacy line, and the shadcn tooling targets v4); no Tailwind (rejected by the clarified spec).

## D3. Radix packages

- **Decision**: The unified `radix-ui` package (1.8) for Dialog, Select, Checkbox, RadioGroup, Tooltip and Slot.
- **Rationale**: One dependency, tree-shaken, and it is what the current shadcn templates use. It supports React 19.
- **Alternatives considered**: Individual `@radix-ui/react-*` packages (rejected: five version pins to keep aligned for no gain).

## D4. Styling helpers

- **Decision**: `class-variance-authority` for variants and sizes, `clsx` plus `tailwind-merge` as a single `cn()` helper, `tw-animate-css` for the Dialog, Select and Tooltip enter/exit animations.
- **Rationale**: This is the standard shadcn composition; each piece is tiny and it keeps variant APIs uniform across components.

## D5. Icons

- **Decision**: `lucide-react` (1.x) for all interface icons. The emoji currently used as icons (💡 👤 ⚠️ ✅ ✨ 🕒 ⏳ 🛡️) are replaced by Lucide icons (for example `Lightbulb`, `User`, `TriangleAlert`, `CircleCheck`, `Sparkles`, `Clock`, `Hourglass`, `ShieldCheck`). Icons are decorative by default (`aria-hidden`) and only exposed with a text label. The Google logo is one `GoogleIcon` component in `packages/ui/src/icons/` replacing two duplicated inline SVGs.
- **Rationale**: Emoji render differently per platform and are announced unpredictably by screen readers. Lucide dropped brand icons, so the multi-colour Google "G" cannot come from it; keeping it as one shared asset is the minimal exception to FR-012.

## D6. Theme switching

- **Decision**: Dark mode is the `.dark` class on `<html>`. A `ThemeProvider` and `useTheme()` in the package manage three states, `light`, `dark` and `system` (default), persist the choice in `localStorage` under `ui-theme`, follow `prefers-color-scheme` while in `system`, and set `color-scheme` on `<html>`. A tiny blocking script (`theme-init`) is inlined in each app's `index.html` and applies the stored or system theme before first paint. During a switch a `data-theme-switching` attribute disables transitions for one frame so nothing animates half-way.
- **Rationale**: This satisfies FR-004 (system detection plus override), SC-003 (no flash, under 100 ms because it is a variable swap) and the rapid-toggling edge case. It also closes the clarify-session gap on theme persistence (storage and the three-state model).
- **Alternatives considered**: Cookie or server-side theme (rejected: no server rendering here); CSS `prefers-color-scheme` only (rejected: no user override).

## D7. Tokens and contrast

- **Decision**: Tokens are the shadcn neutral theme in `oklch`: `background`, `foreground`, `card`, `popover`, `primary`, `secondary`, `muted`, `accent` (each with a `-foreground`), `destructive`, `border`, `input`, `ring`, `radius`, plus three added status families `success`, `warning` and `info` (each with a `-foreground`) because User Story 1 requires semantic success, warning, error and info colors and the neutral theme only has a destructive color. The exact reference values and the list of pairs that must pass are in [contracts/design-tokens.md](contracts/design-tokens.md). `--input` and `--ring` are set to meet 3:1 against the surface they sit on, in both modes (tension T2).
- **Verification**: `tokens.contrast.test.ts` (Vitest, using `culori` for oklch conversion) computes the contrast ratio of every required foreground/background pair in both modes and fails below 4.5:1 for text and 3:1 for control boundaries, focus rings and icons. This covers FR-005 mechanically for tokens, while axe covers the rendered components.
- **Rationale**: The spec's "all token combinations" is only enforceable if the pair list exists in code. The status colors are new, so they cannot be borrowed from a stock theme.
- **Risk**: The reference values were written from the stock theme and the contrast rules, not generated from the shadcn CLI. The first implementation task regenerates them from the CLI and lets the contrast test decide; any pair that fails is adjusted, not waived.

## D8. Responsive behavior

- **Decision**: Use Tailwind's default breakpoints: `sm` 640px and `lg` 1024px (mobile below 640, tablet 640 to 1024, desktop above, matching FR-007). Layout primitives are mobile-first. A Storybook browser test renders the layout stories at 320, 375, 640, 1024 and 2560 px and asserts there is no horizontal overflow (`scrollWidth <= clientWidth`), which is the automated form of SC-004. Below 320 px the long-label behavior (wrap or truncate with a tooltip) is covered by a dedicated story.

## D9. Dialog behavior and the session-expired dialog

- **Decision**: `Dialog` wraps Radix Dialog with focus trapping, a standard backdrop, a close button, Escape and backdrop dismissal, and a `dismissible` prop (default `true`). When `dismissible={false}` Escape, backdrop click and the close button are disabled and no close control is rendered. `SessionExpiredModal` uses `dismissible={false}` with a single sign-in action, exactly like today. It keeps `role="dialog"`, an accessible title and description, and focus on the sign-in button.
- **Rationale**: Resolves tension T1 without changing the security-relevant behavior of the existing flow.

## D10. Storybook and automated checks

- **Decision**: Storybook 10.6 (`@storybook/react-vite`) inside `packages/ui` with `addon-docs`, `addon-themes` (toolbar toggling the `.dark` class), `addon-a11y` and `addon-vitest`. `.storybook/preview.ts` sets `parameters.a11y.test = 'error'` so any axe violation fails the test run. The browser tests run through Vitest with Playwright (Chromium). To cover both themes without duplicating stories, `preview.ts` reads an environment variable (`STORYBOOK_THEME`, `light` or `dark`) for the initial theme global, and the Nx `test` target runs the suite once per theme. Every story of an interactive component includes a `play` function that exercises the keyboard behavior that applies to it (Tab and Shift+Tab, Enter, Space, Escape, arrows), which covers FR-006 (tension T6).
- **Rationale**: One toolchain provides the catalog (FR-010), the axe gate for both themes (FR-015, SC-002) and keyboard coverage. The two-run theme matrix avoids hand-copying every story.
- **Risk**: Running the add-on across a theme matrix is the least-documented part of this setup. The first Storybook task is a short spike that proves one component fails correctly under both themes before the rest is built; if the matrix approach does not work, fall back to explicit `Dark` story variants generated by a helper.
- **CI**: Playwright needs a Chromium download and a static Storybook build in CI, which means a workflow (see D12).

## D11. Behavior preservation for the migrated app (FR-013)

- **Decision**: Add Vitest, jsdom and Testing Library to `idea-collector-frontend` and write characterization tests for the five existing components **before** changing them. They query by role and text, never by CSS class, so they keep passing after the markup changes. They cover: sign-in button calls `authService.initiateGoogleLogin`; the idea form is disabled when empty or over 5000 characters, submits, clears the draft, shows a status message on success and an alert on failure; the list shows loading, empty and populated states with the idea count; the header shows the user and signs out; the session-expired dialog shows its title and copy when open, renders nothing when closed, cannot be dismissed with Escape or an outside click, and its action calls `initiateGoogleLogin`. The tests deliberately do not assert `role="dialog"`: the current markup is a plain `div`, and the migration adds the dialog role, focus trap and accessible name as an accessibility improvement, not a behavior change.
- **Rationale**: User Story 2 scenario 4 says each flow "behaves exactly as before". Tests that pass on the old code and unchanged on the new code are the only direct evidence of that.
- **Alternatives considered**: Manual checking only (rejected: it cannot prove "exactly as before"); end-to-end browser tests of the whole app (rejected: needs a login against real Cognito).

## D12. CI

- **Decision**: A dedicated workflow `ui.on_pull_request.yml` runs `lint`, `typecheck`, `test` (unit plus Storybook/Playwright for both themes) and `build-storybook` for `packages/ui`, uploading the static catalog as a build artifact. Because this edits `.github/workflows/`, it is a gated task (T018) that needs your explicit approval, and since Principle III says every package MUST have its own workflow it must land in the same PR as the package, not after it. A second gated task (T019) adds a `Test Frontend` step to `idea-collector.on_pull_request.yml`: the existing pipeline lints and builds `idea-collector-frontend` when `packages/ui` changes (Nx treats it as an affected dependent) but does not run tests, so without T019 the characterization tests that prove FR-013 would only run locally.
- **Rationale**: Principle III and `AGENTS.md` require a workflow for a new package. Following feature 003's pattern, a standalone path-filtered workflow avoids editing the shared `detect` action, which treats root `package.json` or common-action changes as global and re-runs every pipeline.
- **Note**: this feature edits the root `package.json` (`workspaces`) and `pnpm-lock.yaml`, which `detect` treats as global changes. The PR that adds the package therefore runs every pipeline, **and merging it to `main` runs Terraform Apply for both idea-collector and commifra** even though no infrastructure file changed (the same happened after the standardize-commits PR). The applies should be no-ops. Before merging that PR, confirm both Terraform Plan checks report no changes; the lockfile change cannot be avoided.

## D13. Preventing global style leakage (FR-009)

- **Decision**:
  1. `theme.css` contains tokens and utilities only. It does **not** import Tailwind's base reset (preflight). Each application imports `tailwindcss/preflight.css` itself, in the `base` cascade layer, and idea-collector does so only at the point its screens are fully on the library. Consumers use the layered import form (`layer(theme)`, `layer(base)`, `layer(utilities)`); the granular imports compile without layers (checked against Tailwind 4.3.3), which would put the reset in the same unlayered cascade as legacy CSS, where source order and specificity decide.
  2. Component classes are Tailwind utilities, so nothing is styled by a bare element selector.
  3. The token variables live on `:root` and `.dark` under the unprefixed shadcn names (so the stock tooling works). To avoid collisions with legacy CSS, the migration's first step renames the legacy variables in `App.css` with a `--legacy-` prefix; `App.css` is deleted when the last screen is migrated.
- **Rationale**: Covers FR-009 and the "side-by-side with legacy views" edge case while keeping shadcn compatibility. Prefixing the new tokens instead (supported by Tailwind) was rejected because it breaks the standard component templates.

## D14. Fonts

- **Decision**: The Tailwind default system font stack (`font-sans`); no web font is loaded, matching the clarified answer.

## Constitution notes

- Principle III gate: the CI workflow for the new package needs explicit approval (D12).
- Principle IV: the migration must not modify the tracked `apps/idea-collector/frontend/.env` or any Cognito value.
- `AGENTS.md` requires lint, typecheck and tests to pass before any PR is opened.

## Open items for the owner

1. Approve the two workflow edits at the start of implementation (D12): the new `ui.on_pull_request.yml` (T018) and the `Test Frontend` step in `idea-collector.on_pull_request.yml` (T019). The first PR cannot merge without them.
2. ~~Confirm the spec amendment for tension T1.~~ Resolved: applied to the spec (FR-016, scenarios 3 and 6).
3. Confirm that `--input` and `--ring` may be darker than the stock neutral theme to meet WCAG 3:1 (tension T2).
