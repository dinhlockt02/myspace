# Tasks: Consistent Design System and Shared UI Library

**Feature**: `004-design-system`
**Input**: [spec.md](spec.md), [plan.md](plan.md), [data-model.md](data-model.md), [contracts/](contracts/), [research.md](research.md), [quickstart.md](quickstart.md)

**Tests**: Included. The plan commits to token contrast tests, Storybook axe and keyboard tests, responsive tests, and characterization tests for the migrated app; FR-005, FR-006, FR-013, FR-015 and SC-002 to SC-004 are only provable with them. Write each story's tests first and confirm they fail before implementing.

**Conventions for every task**
- New package: `packages/ui` (`@myspace/ui`), consumed from source. Application: `apps/idea-collector/frontend`.
- TypeScript is strict, and the repo's pinned `typescript` (`~5.7.2`) is kept; do not upgrade it.
- Styling uses Tailwind utilities from the tokens in [contracts/design-tokens.md](contracts/design-tokens.md); no raw colors, no element selectors, no base reset in `theme.css`.
- Components follow [contracts/ui-package-api.md](contracts/ui-package-api.md): props extend the native element or Radix part, `className` merges through `cn`, `ref` is forwarded, icons are decorative (`aria-hidden="true"`) unless labelled.
- Never modify the tracked `apps/idea-collector/frontend/.env`, any Cognito value, or any file under `.github/workflows/` except in the gated tasks T018 and T019 (`AGENTS.md`).
- Work on `feat/004` (a non-protected branch).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the package and wire it into the workspace

- [X] T001 Create `packages/ui/package.json`: name `@myspace/ui`, `private: true`, `type: module`, `exports` of `.` to `./src/index.ts`, `./theme.css` to `./src/styles/theme.css` and `./theme-init` to `./src/theme/theme-init.ts` (no build step; consumed from source); `peerDependencies` `react` and `react-dom` `^19.0.0`; `dependencies` `radix-ui` (1.8), `class-variance-authority`, `clsx`, `tailwind-merge`, `tw-animate-css`, `lucide-react` (1.x); `devDependencies` `tailwindcss` and `@tailwindcss/vite` (4.3), `storybook`, `@storybook/react-vite`, `@storybook/addon-a11y`, `@storybook/addon-docs`, `@storybook/addon-themes`, `@storybook/addon-vitest` (all 10.6), `vitest` (5), `@vitest/browser` and `@vitest/browser-playwright` (`@vitest/browser` is a peer of `@storybook/addon-vitest`), `playwright`, `jsdom`, `@testing-library/react`, `culori`, `typescript` (`~5.7.2`), `@types/react`, `@types/react-dom`, and the eslint packages already used by the frontend; scripts `lint`, `typecheck`, `test`, `storybook`, `build-storybook`
- [X] T002 [P] Add `packages/*` to the `packages:` list in `pnpm-workspace.yaml` and add `"packages/ui"` to the `workspaces` array in the root `package.json`; change nothing else in either file
- [X] T003 [P] Create `packages/ui/tsconfig.json` with the same strictness as `apps/idea-collector/frontend/tsconfig.json` (`strict`, `noUnusedLocals`, `noUnusedParameters`, `noFallthroughCasesInSwitch`, `noUncheckedSideEffectImports`, `jsx: react-jsx`, `moduleResolution: bundler`, `noEmit`), `include` of `src` and `.storybook`
- [X] T004 [P] Create `packages/ui/eslint.config.js` mirroring `apps/idea-collector/frontend/eslint.config.js` (same plugins and rules) with `ignores` of `dist` and `storybook-static`
- [X] T005 [P] Add `storybook-static/` and `*.tsbuildinfo` to the root `.gitignore`
- [X] T006 Create `packages/ui/project.json` (Nx project `ui`, `projectType: library`, `sourceRoot: packages/ui/src`, tags `scope:shared` and `type:lib`) with `nx:run-commands` targets `lint` (`eslint .`), `typecheck` (`tsc --noEmit`), `test` (`vitest run`), `storybook` (`storybook dev -p 6006`) and `build-storybook` (`storybook build`, `outputs` of `{projectRoot}/storybook-static`, cache on), all with `cwd` of `packages/ui`
- [X] T007 Run `pnpm install` from the repository root (depends on T001, T002) so the workspace resolves `@myspace/ui`; commit the resulting `pnpm-lock.yaml` change and confirm `pnpm nx show projects` lists `ui`; install Playwright's Chromium with `pnpm exec playwright install chromium`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Tooling every story needs, the theme-matrix spike, and the characterization tests that must exist before any app code is changed

**⚠️ CRITICAL**: No user story work can begin until this phase is complete, except T018 and T019, which need explicit approval and gate only the **merge** of the first PR (they must ship with the package), not development

- [X] T008 [P] Create `packages/ui/src/lib/cn.ts` exporting `cn(...inputs)` built from `clsx` and `tailwind-merge`, and `packages/ui/src/lib/cn.test.ts` covering merge of conflicting Tailwind classes, falsy values and conditional classes
- [X] T009 [P] Create the Storybook shell in `packages/ui/.storybook/`: `main.ts` (framework `@storybook/react-vite`, stories glob `../src/**/*.stories.@(ts|tsx)`, addons `addon-docs`, `addon-a11y`, `addon-themes`, `addon-vitest`, a `viteFinal` adding `@tailwindcss/vite`), `preview.ts` importing `../src/styles/storybook.css` with `parameters.a11y.test = 'error'` (any axe violation fails), and `packages/ui/src/styles/storybook.css` containing `@layer theme, base, components, utilities; @import "tailwindcss/theme.css" layer(theme); @import "./theme.css"; @import "./animate.css"; @import "tailwindcss/preflight.css" layer(base); @import "tailwindcss/utilities.css" layer(utilities); @source "..";` (preflight is allowed here because Storybook is the package's own sandbox)
- [X] T010 [P] Create `packages/ui/vitest.config.ts` with three projects: `unit` (jsdom, `include` of `src/**/*.test.{ts,tsx}` and `exclude` of `src/**/*.browser.test.{ts,tsx}`), `browser` (browser mode through `@vitest/browser-playwright`, Chromium headless, `include` of `src/**/*.browser.test.{ts,tsx}`: tests that need real layout and computed styles) and `storybook` (browser mode, Chromium headless, using the `storybookTest` plugin from `@storybook/addon-vitest/vitest-plugin`, which runs the stories), (no `.storybook/vitest.setup.ts` is needed: `@storybook/addon-vitest` applies the preview annotations itself since Storybook 10.3); set `passWithNoTests: true` at the top level of the config (Vitest does not allow it per project) so the `test` target is green before the first story or browser test exists (removed again in T042)
- [X] T011 Theme-matrix spike (depends on T009, T010): in `packages/ui/src/spike.stories.tsx` add a story with a deliberate axe violation (an icon-only `<button>` with no accessible name). In `.storybook/preview.ts` read `import.meta.env.STORYBOOK_THEME` (`light` or `dark`) to set the initial theme global. Prove with `STORYBOOK_THEME=light pnpm nx run ui:test -- --project storybook` and the same for `dark` that the story fails in both runs and passes in both once the label is added. Record the result in `research.md` D10; if the environment-variable matrix does not work, switch to explicit `Dark` story variants generated by a helper and record that decision. Delete `spike.stories.tsx` when done
- [X] T012 [P] Add test tooling to the app: in `apps/idea-collector/frontend/package.json` add dev dependencies `vitest` (5), `jsdom`, `@testing-library/react`, `@testing-library/user-event`, `@testing-library/jest-dom` and a `test` script of `vitest run`; add a `test` target to `apps/idea-collector/frontend/project.json` (`nx:run-commands`, `cwd` of `apps/idea-collector/frontend`, cache on); create `apps/idea-collector/frontend/vitest.config.ts` (jsdom, `setupFiles` of `src/test/setup.ts`, `include` of `src/**/*.test.{ts,tsx}`) and `apps/idea-collector/frontend/src/test/setup.ts` importing `@testing-library/jest-dom/vitest`
- [X] T013 [P] Characterization test for the sign-in prompt in `apps/idea-collector/frontend/src/components/AuthPrompt.test.tsx`, passing against the **current** code: heading "Welcome to Idea Collector"; the button named "Sign in with Google" calls `authService.initiateGoogleLogin` once when clicked (mock `../services/auth`); an `error` prop renders an element with `role="alert"` containing the message; `loading` shows "Signing in..." and no sign-in button. Query by role and text only, never by CSS class
- [X] T014 [P] Characterization test for the header in `apps/idea-collector/frontend/src/components/Header.test.tsx`: shows the app title, the user's email, the name when present and no name element when absent; the "Sign Out" button calls `onLogout` once
- [X] T015 [P] Characterization test for the idea form in `apps/idea-collector/frontend/src/components/IdeaForm.test.tsx`: the submit button is disabled when the draft is empty, whitespace-only, or longer than 5000 characters, and enabled otherwise; the counter reads `N / 5000`; typing calls `onDraftChange`; submitting calls `onSubmit(draft)`, then `onClearDraft`, and shows an element with `role="status"` reading "Your idea has been recorded securely!"; a rejected submit shows an element with `role="alert"` with the error message or "Failed to submit idea. Please try again."; while `submitting` the button reads "Submitting..." and the textarea is disabled
- [X] T016 [P] Characterization test for the idea list in `apps/idea-collector/frontend/src/components/IdeaList.test.tsx`: loading with no ideas shows "Loading your ideas..."; an empty list shows "No ideas submitted yet"; a populated list shows each idea's text and a count reading "N ideas" (and "1 idea" for one); the heading "Your Collection" is present in every state
- [X] T017 [P] Characterization test for the session-expired dialog in `apps/idea-collector/frontend/src/components/SessionExpiredModal.test.tsx`: renders nothing when `isOpen` is false; when open shows the heading "Session Expired" and the idle-timeout copy; the button "Sign in with Google to Resume" calls `authService.initiateGoogleLogin`; there is no close control; pressing Escape and clicking outside the dialog do not remove it. Do **not** assert `role="dialog"` (the current markup is a plain `div`; the migration adds the role)
- [X] T018 CI workflow for the new package, landing in the same PR as the package itself (constitution Principle III: every package MUST have its own workflow): create `.github/workflows/ui.on_pull_request.yml` (standalone, path-filtered to `packages/ui/**` and itself) running `lint`, `typecheck`, `test` (the `unit` project, the `browser` project, and the `storybook` project once with `STORYBOOK_THEME=light` and once with `STORYBOOK_THEME=dark`, installing Playwright Chromium) and `build-storybook`, and uploading `packages/ui/storybook-static` as a build artifact (**requires explicit approval; `AGENTS.md` forbids changing CI workflows without it. It gates the merge of the first PR, not local development: do not start it unless the user instructs it**)
- [X] T019 Run the migrated app's tests in CI: edit `.github/workflows/idea-collector.on_pull_request.yml` to add a step `pnpm nx run idea-collector-frontend:test` between the "Lint Frontend" and "Build Frontend" steps, so the characterization tests that prove FR-013 are enforced and not only run locally; make no other change to that workflow (**requires explicit approval, same gate as T018: do not start it unless the user instructs it**)

**Checkpoint**: tooling works in both packages, the spike result is recorded, T013 to T017 pass against the unmodified app, and T018 and T019 are approved and done before the first PR merges

---

## Phase 3: User Story 1 - Cohesive Visual Identity and Unified Design Tokens (Priority: P1) 🎯 MVP

**Goal**: One token set (colors in light and dark, radii, type and spacing scales) that every component draws from, with WCAG 2.1 AA contrast guaranteed by a test.

**Independent Test**: `pnpm nx run ui:test -- --project unit` passes the token contrast and theme-file tests, and the catalog's tokens page shows the palette in both modes.

### Tests for User Story 1

> Write these first and confirm they FAIL before implementing.

- [X] T020 [P] [US1] Create `packages/ui/src/tokens/tokens.contrast.test.ts` that computes WCAG contrast with `culori` for every pair in [contracts/design-tokens.md](contracts/design-tokens.md) (26 pairs) in both modes and fails below 4.5:1 for `text` pairs and below 3:1 for `control` pairs; it must also fail when a color token lacks a light or a dark value
- [X] T021 [P] [US1] Create `packages/ui/src/styles/theme-css.test.ts` that reads `packages/ui/src/styles/theme.css` and fails if it contains any element selector (`body`, `html`, `h1`-`h6`, `a`, `button`, `input`, `*`), any `@import` of `tailwindcss/preflight`, or any token that is not defined in both `:root` and `.dark` (FR-009)
- [X] T022 [P] [US1] Create `packages/ui/src/styles/theme-coexistence.browser.test.tsx` (`browser` project, real browser) proving FR-009 and the "Side-by-Side Coexistence with Legacy Views" edge case: render plain unstyled HTML (`h1`, `p`, `a`, `button`, `input`, `ul`, `table`) in a container, record each element's computed style, then inject the raw contents of `theme.css` (imported with `?raw`) as a `<style>` element and assert every recorded computed style is unchanged; repeat with the layered consumer stylesheet from `contracts/consumer-integration.md` section 3 (no base reset) so a consumer that has not adopted the reset sees no change

### Implementation for User Story 1

- [X] T023 [US1] Create `packages/ui/src/tokens/tokens.ts` exporting the token manifest (name, group, `light`, `dark`) and the required `ContrastPair` list. First regenerate the stock shadcn neutral theme values from the shadcn CLI in a scratch directory (not in the repo) and compare them with [contracts/design-tokens.md](contracts/design-tokens.md); record every difference in `research.md` D7. Use the contract's values: `muted-foreground` light `oklch(0.5 0 0)`, `input` and `ring` `oklch(0.62 0 0)` light and `oklch(0.58 0 0)` dark, plus the added `destructive-foreground`, `success`, `warning`, `info` and their foregrounds; keep `border` decorative. Radius base `0.625rem`
- [X] T024 [US1] Create `packages/ui/src/styles/theme.css` (depends on T023): the token custom properties under `:root` (light) and `.dark` (dark) with the unprefixed names, an `@theme inline` block mapping every token to Tailwind color and radius utilities (small, medium, large radii derived from `--radius`), and `@custom-variant dark (&:is(.dark *))`. No element selectors, no base reset and no `@import "tw-animate-css"` (it defines `@utility` rules, which Tailwind rejects inside a `layer(theme)` import): also create `packages/ui/src/styles/animate.css` containing `@import "tw-animate-css";` and export it as `@myspace/ui/animate.css`. Both tests T020 and T021 must now pass
- [X] T025 [US1] Create `packages/ui/src/tokens/tokens.stories.tsx`, a documentation story that renders every color token as a swatch with its name and light/dark value, the Tailwind type scale, the spacing scale, the radii and the shadow scale (`shadow-xs` to `shadow-lg`), so typography, spacing, radii and elevations are previewable (FR-001, US1 scenarios 1 and 3)

**Checkpoint**: US1 is independently demonstrable: tokens exist, contrast is proven, the palette is browsable

---

## Phase 4: User Story 2 - Standard Reusable UI Component Library for Common Interactions (Priority: P1)

**Goal**: The 12 first-release components and 3 layout primitives with every state in both themes, and every existing idea-collector screen migrated onto them with behavior unchanged.

**Independent Test**: Run the Storybook catalog and exercise each component's states; run `pnpm nx run idea-collector-frontend:test` and confirm the characterization tests from Phase 2 pass unchanged on the migrated app.

> Each component task creates the component and its stories. Stories must show every variant and state from [data-model.md](data-model.md) (default, hover, focus, active, disabled, error where they apply); axe runs over them automatically (`parameters.a11y.test = 'error'`).

### Components and layout primitives

- [X] T026 [P] [US2] Create `packages/ui/src/components/button.tsx` and `button.stories.tsx`: `cva` variants `default`, `secondary`, `outline`, `ghost`, `destructive`, `link` and sizes `sm`, `default`, `lg`, `icon`; `asChild` via Radix `Slot`; disabled is not focusable; visible `ring` focus
- [X] T027 [P] [US2] Create `packages/ui/src/components/input.tsx` and `input.stories.tsx`: native `<input>` with an `invalid` prop that sets `aria-invalid="true"`, uses `border-input` for the boundary and `bg-background` for the fill (no tinted fill), `destructive` border when invalid
- [X] T028 [P] [US2] Create `packages/ui/src/components/textarea.tsx` and `textarea.stories.tsx` with the same contract as `Input` (`invalid`, `border-input`, `aria-invalid`)
- [X] T029 [P] [US2] Create `packages/ui/src/components/card.tsx` and `card.stories.tsx` exporting `Card`, `CardHeader`, `CardTitle` (renders the heading element chosen by an `as` prop), `CardDescription`, `CardContent`, `CardFooter`
- [X] T030 [P] [US2] Create `packages/ui/src/components/dialog.tsx` and `dialog.stories.tsx` wrapping Radix Dialog (`Dialog`, `DialogTrigger`, `DialogContent`, `DialogHeader`, `DialogTitle`, `DialogDescription`, `DialogFooter`, `DialogClose`) with focus trapping, a standard backdrop, a close button, and a `dismissible` prop whose default is `true`. When `dismissible={false}`: Escape, backdrop click and the close button do not dismiss and no close control renders (FR-016). `DialogTitle` and `DialogDescription` are required. Add `play` tests for both modes: dismissible closes on Escape, the close button and a backdrop click and returns focus to the trigger; non-dismissible stays open on all three
- [X] T031 [P] [US2] Create `packages/ui/src/components/alert.tsx` and `alert.stories.tsx` with `Alert`, `AlertTitle`, `AlertDescription` and variants `default`, `destructive`, `success`, `warning`, `info`; `role="alert"` for `destructive` and `warning`, `role="status"` for the others; optional decorative Lucide icon
- [X] T032 [P] [US2] Create `packages/ui/src/components/select.tsx` and `select.stories.tsx` wrapping Radix Select (`Select`, `SelectTrigger`, `SelectContent`, `SelectItem`, `SelectValue`) with an `invalid` prop and Lucide chevron and check icons
- [X] T033 [P] [US2] Create `packages/ui/src/components/checkbox.tsx` and `checkbox.stories.tsx` wrapping Radix Checkbox with `invalid`, a Lucide check icon and indeterminate support
- [X] T034 [P] [US2] Create `packages/ui/src/components/radio-group.tsx` and `radio-group.stories.tsx` wrapping Radix RadioGroup (`RadioGroup`, `RadioGroupItem`) with `invalid`
- [X] T035 [P] [US2] Create `packages/ui/src/components/tooltip.tsx` and `tooltip.stories.tsx` wrapping Radix Tooltip (`TooltipProvider`, `Tooltip`, `TooltipTrigger`, `TooltipContent`); opens on hover and keyboard focus; its content is never the only way to get information
- [X] T036 [P] [US2] Create `packages/ui/src/components/spinner.tsx` and `spinner.stories.tsx` using Lucide `LoaderCircle`, sizes `sm`, `default`, `lg`, `role="status"` with a visually hidden `label` (default "Loading")
- [X] T037 [P] [US2] Create `packages/ui/src/components/badge.tsx` and `badge.stories.tsx` with variants `default`, `secondary`, `outline`, `destructive` (non-interactive `<span>`)
- [X] T038 [P] [US2] Create `packages/ui/src/icons/google-icon.tsx` and a story: the four-color Google "G" as one SVG component (replacing the two duplicated inline SVGs in `AuthPrompt.tsx` and `SessionExpiredModal.tsx`), prop `size` default 20, decorative by default (`aria-hidden="true"`); its brand colors are the only raw colors allowed in this feature
- [X] T039 [P] [US2] Create `packages/ui/src/layout/page-container.tsx` and its stories: `as` and `className` props; full width with horizontal padding below 640px and a centered maximum width from 1024px up
- [X] T040 [P] [US2] Create `packages/ui/src/layout/app-header.tsx` and its stories with `brand` and `actions` slots; row layout, and below 640px the actions wrap under the brand without horizontal overflow
- [X] T041 [P] [US2] Create `packages/ui/src/layout/sidebar-layout.tsx` and its stories with `sidebar` and children slots and a `sidebarWidth` prop; side by side from 1024px, stacked below
- [X] T042 [US2] Create `packages/ui/src/index.ts` exporting every component, layout primitive and `GoogleIcon` and `cn` (depends on T026 to T041) remove `passWithNoTests: true` from the `storybook` and `browser` projects in `packages/ui/vitest.config.ts` now that stories and browser tests exist (added in T010), and run `pnpm nx run ui:typecheck` and `pnpm nx run ui:lint`; export no Lucide icons

### Migrating idea-collector (FR-013), in this order

- [X] T043 [US2] Rename every CSS custom property in `apps/idea-collector/frontend/src/App.css` with a `--legacy-` prefix (for example `--primary` becomes `--legacy-primary`, `--danger`, `--radius-sm`, `--radius-md`, `--radius-lg`, `--font-sans` and all others) and update every `var(--...)` use in the same file; this is purely mechanical and visually a no-op. Run the characterization tests T013 to T017: they must still pass
- [X] T044 [US2] Add the library to the app (depends on T042, T043): in `apps/idea-collector/frontend/package.json` add `"@myspace/ui": "workspace:*"`, `tailwindcss`, `@tailwindcss/vite` and `lucide-react`; add `tailwindcss()` to `plugins` in `apps/idea-collector/frontend/vite.config.ts`; create `apps/idea-collector/frontend/src/index.css` following [contracts/consumer-integration.md](contracts/consumer-integration.md) section 3 (`@layer theme, base, components, utilities; @import "tailwindcss/theme.css" layer(theme); @import "@myspace/ui/theme.css"; @import "tailwindcss/utilities.css" layer(utilities); @import "@myspace/ui/animate.css"; @source "../../../../packages/ui/src";`, the layered form so the base reset can never outrank legacy CSS) **without** the base reset; confirm in the build output that the token variables are present and utilities resolve, (`theme.css` and `animate.css` must stay unlayered: Tailwind rejects `@theme`, `@custom-variant` and `@utility` inside a `layer(...)` import); import it in `src/main.tsx`. Run the tests and `pnpm nx run idea-collector-frontend:build`
- [X] T045 [US2] Migrate the shell in `apps/idea-collector/frontend/src/App.tsx`: replace the three `app-container` wrappers (loading, signed-out, workspace) with `PageContainer` and the loading state with `Spinner`; keep every hook call, branch and string unchanged. Run the tests
- [X] T046 [P] [US2] Migrate `apps/idea-collector/frontend/src/components/Header.tsx` to `AppHeader` with `Badge` and `Button` (`variant="outline"`, `size="sm"`), replacing the 💡 and 👤 emoji with decorative Lucide `Lightbulb` and `User` icons; keep the `title` attributes and the sign-out behavior. Run `Header.test.tsx`
- [X] T047 [P] [US2] Migrate `apps/idea-collector/frontend/src/components/AuthPrompt.tsx` to `Card`, `Alert` (`variant="destructive"`, keeping `role="alert"`), `Spinner`, `Button` and the shared `GoogleIcon`, replacing emoji with decorative Lucide icons; keep the `aria-label="Sign in with Google"` and all copy. Run `AuthPrompt.test.tsx`
- [X] T048 [P] [US2] Migrate `apps/idea-collector/frontend/src/components/IdeaForm.tsx` to `Card`, `Textarea`, `Alert` (destructive with `role="alert"`, success with `role="status"`) and `Button`, replacing emoji with decorative Lucide icons; keep the 5000-character limit, `maxLength`, the counter, the disabled logic and every string. Run `IdeaForm.test.tsx`
- [X] T049 [P] [US2] Migrate `apps/idea-collector/frontend/src/components/IdeaList.tsx` to `Card`, `Badge` and `Spinner` for the loading, empty and populated states and the count badge, replacing emoji with decorative Lucide icons (`Sparkles`, `Clock`); keep the date formatting and all copy. Run `IdeaList.test.tsx`
- [X] T050 [P] [US2] Migrate `apps/idea-collector/frontend/src/components/SessionExpiredModal.tsx` to `Dialog` with `dismissible={false}`, `DialogTitle` "Session Expired", a `DialogDescription`, an `Alert` for the preserved-draft notice, and `Button` with `GoogleIcon` labelled "Sign in with Google to Resume"; focus starts on that button; no close control; keep the early return when `isOpen` is false. The dialog now carries `role="dialog"` as an accessibility improvement. Run `SessionExpiredModal.test.tsx`
- [X] T051 [US2] Finish the migration (depends on T045 to T050): delete `apps/idea-collector/frontend/src/App.css` and its import, add `@import "tailwindcss/preflight.css" layer(base);` to `src/index.css` between the theme and utilities imports, and run the full app test suite and `pnpm nx run idea-collector-frontend:build`
- [X] T052 [US2] Create `apps/idea-collector/frontend/src/migration.test.ts` asserting `src/App.css` no longer exists and that no `.tsx` or `.css` file under `src` contains a raw color literal (`#rgb`/`#rrggbb`, `rgb(`, `hsl(`), so the "no raw colors" rule of FR-013 and SC-001 stays enforced

**Checkpoint**: US2 is independently testable: the catalog shows every component and state, and the migrated app passes the unchanged characterization tests

---

## Phase 5: User Story 3 - Seamless Theme Switching Between Light and Dark Modes (Priority: P2)

**Goal**: Light, dark and system themes that switch instantly, persist, and never flash.

**Independent Test**: Toggle the theme in the catalog and in the app, confirm the OS preference is the default, and confirm both-theme axe runs pass.

### Tests for User Story 3

> Write these first and confirm they FAIL before implementing.

- [X] T053 [P] [US3] Create `packages/ui/src/theme/theme.test.tsx` (jsdom, with `matchMedia` and `localStorage` mocks): the default is `system`; `system` resolves to `dark` when `prefers-color-scheme: dark` matches and to `light` otherwise; `setTheme('dark')` adds the `dark` class to `<html>`, sets `color-scheme` and writes `ui-theme`; a stored value other than `light`, `dark` or `system` falls back to `system`; a `localStorage` that throws keeps working in memory and falls back to `system` on reload; an OS preference change updates `resolvedTheme` while the value is `system` without writing storage; 50 rapid `setTheme` calls end in the last requested state with no leftover `data-theme-switching` attribute; the `theme-init` script text applied to a fresh document sets or omits the `dark` class from the stored value or the OS preference

### Implementation for User Story 3

- [X] T054 [US3] Create `packages/ui/src/theme/theme-init.ts` exporting a string constant `themeInitScript` containing a self-contained script that reads `ui-theme` (default `system`), resolves it against `prefers-color-scheme`, and sets the `dark` class and `color-scheme` on `document.documentElement` inside a try/catch (storage may be unavailable)
- [X] T055 [US3] Create `packages/ui/src/theme/ThemeProvider.tsx` and `packages/ui/src/theme/useTheme.ts` (depends on T054): `ThemeProvider` props `defaultTheme` (default `system`) and `storageKey` (default `ui-theme`); `useTheme()` returns `{ theme, resolvedTheme, setTheme }` with `theme` in `light`, `dark`, `system`; sets `data-theme-switching` on `<html>` for one frame around each change so no transition runs half-way; follows OS changes only while `system`
- [X] T056 [US3] Export `ThemeProvider`, `useTheme` and `themeInitScript` from `packages/ui/src/index.ts`; wire the Storybook theme toolbar in `packages/ui/.storybook/preview.ts` with `withThemeByClassName` from `@storybook/addon-themes` (light and dark) and keep the `STORYBOOK_THEME` initial-theme handling proven in T011; run `STORYBOOK_THEME=dark pnpm nx run ui:test -- --project storybook` and fix every violation it finds in the dark theme
- [X] T057 [US3] Integrate the theme into the app: inline the contents of `themeInitScript` as a blocking `<script>` in `<head>` of `apps/idea-collector/frontend/index.html` before the Google script and any rendering, wrap `<App />` in `<ThemeProvider defaultTheme="system">` in `apps/idea-collector/frontend/src/main.tsx`, and add `apps/idea-collector/frontend/src/theme-init-sync.test.ts` that fails if the script text in `index.html` differs from `themeInitScript` (guards drift). Do not add a theme switcher control to the app (FR-004 asks for capability, not a UI)
- [X] T058 [US3] Create `packages/ui/src/theme/theme.stories.tsx` with a story containing a theme control (light, dark, system) and a `play` function that toggles through all three states and then 20 times rapidly, asserting the `dark` class matches the last choice (SC-003 and the rapid-toggling edge case)

**Checkpoint**: US3 works independently: persistence, system default, no flash, and the dark-theme axe run is green

---

## Phase 6: User Story 4 - Accessible and Responsive Multi-Device Experience (Priority: P3)

**Goal**: Keyboard operability, screen-reader names, and layouts that hold from 320px to 2560px, all proven by tests.

**Independent Test**: The keyboard `play` tests and the responsive test pass in both themes; a hand check with Tab, Shift+Tab, Enter, Space, Escape and arrows works across the catalog.

### Tests and implementation for User Story 4

- [X] T059 [P] [US4] Add keyboard `play` tests to the stories of the text-entry and action controls: `packages/ui/src/components/button.stories.tsx` (Tab focuses, Enter and Space activate, disabled is skipped by Tab), `input.stories.tsx` and `textarea.stories.tsx` (Tab focus, typing, `aria-invalid` and the described-by message when invalid); fix any component gap the tests reveal
- [X] T060 [P] [US4] Add keyboard `play` tests to the selection controls: `packages/ui/src/components/select.stories.tsx` (arrow keys move, Enter or Space select, Escape closes, type-ahead), `checkbox.stories.tsx` (Space toggles) and `radio-group.stories.tsx` (arrow keys move and select, Tab leaves the group); fix any gap
- [X] T061 [P] [US4] Add keyboard `play` tests to `packages/ui/src/components/tooltip.stories.tsx` (opens on keyboard focus, closes on Escape) and extend `dialog.stories.tsx` (Tab and Shift+Tab stay trapped inside, focus returns to the trigger); fix any gap
- [X] T062 [P] [US4] Create `packages/ui/src/layout/layout.responsive.browser.test.tsx` (`browser` project) that renders the `PageContainer`, `AppHeader` and `SidebarLayout` stories at widths 320, 375, 640, 1024 and 2560 px and asserts `document.documentElement.scrollWidth <= document.documentElement.clientWidth` at each, plus that `SidebarLayout` is stacked below 1024px and side by side from 1024px, and that `AppHeader` actions wrap below 640px (SC-004, FR-007)
- [X] T063 [P] [US4] Add edge-case stories in `packages/ui/src/layout/edge-cases.stories.tsx` with `play` assertions: a viewport narrower than 320px where long labels wrap or truncate with a `Tooltip` and nothing overflows horizontally; content at 200% font scale where cards, dialogs and button labels grow without breaking the page flow; very long unbroken text inside `Card` and `Badge`
- [X] T064 [P] [US4] Enforce screen-reader names: make `Button` with `size="icon"` require an `aria-label` or `aria-labelledby` through its TypeScript props in `packages/ui/src/components/button.tsx`, add an icon-only button story in `button.stories.tsx`, and add tests in `packages/ui/src/components/alert.stories.tsx` that destructive and warning alerts expose `role="alert"` and the other variants `role="status"`, in `spinner.stories.tsx` that the spinner exposes `role="status"` with its label, and in `badge.stories.tsx` that a `Badge` never renders empty (it always has visible text or an `aria-label`) and that no status meaning is carried by color alone (User Story 4 scenario 3)
- [X] T065 [P] [US4] Support operating-system high-contrast (forced colors) in `packages/ui/src/components/` (`button.tsx`, `input.tsx`, `textarea.tsx`, `select.tsx`, `checkbox.tsx`, `radio-group.tsx`, `dialog.tsx`, `spinner.tsx`): add `forced-colors:` variants so control boundaries and focus outlines stay visible; add `packages/ui/src/components/forced-colors.stories.tsx` documenting it, verified by hand per quickstart scenario 11

**Checkpoint**: All four stories work independently; keyboard, responsive and screen-reader checks pass in both themes

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation and full verification

- [X] T066 [P] Create `packages/ui/README.md` documenting what the package contains, how to run Storybook and the tests, how to add a component following the existing shape, how tokens and the contrast test work, and a link to [contracts/consumer-integration.md](contracts/consumer-integration.md)
- [X] T067 [P] Add a `packages/ui` line to the repository layout block in the root `README.md` and a one-line mention of the Storybook catalog (`pnpm nx run ui:storybook`) in its Getting started section
- [X] T068 [P] Add quickstart scenario 11 to `specs/004-design-system/quickstart.md`: with the operating system in high-contrast (forced colors) mode, open the catalog and the app; expected: control boundaries and focus outlines stay visible and text stays readable
- [X] T069 Run `pnpm nx run-many -t lint,typecheck,test,build -p ui` and `pnpm nx run-many -t lint,test,build -p idea-collector-frontend` (the app has no working `typecheck` target; see research D15), `pnpm nx run ui:build-storybook`, and the Storybook test run once with `STORYBOOK_THEME=light` and once with `STORYBOOK_THEME=dark`; fix every failure and record the results in the PR description
- [X] T070 Run every scenario in [quickstart.md](quickstart.md) (1 to 11), including the by-hand scenarios on theme switching, keyboard, responsive and the migrated app, and record the results in the PR description

---

## Dependencies & Execution Order

- **Phase 1** has no dependencies; T002 to T005 can run alongside T001, T006 follows T001, T007 needs T001 and T002.
- **Phase 2** depends on Phase 1 and blocks all stories, with one exception: **T018 and T019 need explicit approval and gate only the merge of the first PR**, so development of later phases can proceed on the branch while approval is pending, but the first PR (which introduces the package) cannot merge without them (constitution Principle III). T008, T009, T010 and T012 can run in parallel; T011 needs T009 and T010; T013 to T017 need T012 and can run in parallel with each other and with T008 to T011; T018 needs T006 and T010; T019 needs T013 to T017. The characterization tests (T013 to T017) must pass on the unmodified app **before** T043 starts.
- **US1 (Phase 3)** depends on Phase 2. Tests T020, T021 and T022 first, then T023, T024, T025.
- **US2 (Phase 4)** depends on US1 (components use the tokens). Components T026 to T041 are independent files and can run in parallel; T042 needs all of them; the migration T043 to T052 runs in the listed order after T042, except T046 to T050 which are independent of each other once T045 is done.
- **US3 (Phase 5)** depends on Phase 2 and US1; its dark-theme run (T056) is most useful after US2 components exist, and T057 needs the migrated app (T051).
- **US4 (Phase 6)** depends on US2 (it adds tests and fixes to existing components and layouts). T059 to T065 touch different files and can run in parallel.
- **Phase 7** depends on the stories it documents.

```text
Phase 1 -> Phase 2 (T011 spike, T013-T017 characterization tests)
              |  \-> T018, T019 (approval; must ship with the first PR)
              v
        US1 tokens (T020-T025)
              |
              v
        US2 components (T026-T042) -> migration (T043-T052)
              |                              |
              +-> US3 theme (T053-T058) <----+ (T057 needs T051)
              |
              +-> US4 accessibility + responsive (T059-T065)
                                  |
                                  v
                          Phase 7 (T066-T070)
```

## Parallel Execution Examples

- **Setup**: after T001, run T002, T003, T004, T005 together.
- **Foundational**: T008, T009, T010 and T012 together; then T013 to T017 together.
- **US1**: T020, T021 and T022 together (tests), then T023 before T024.
- **US2 components**: T026 to T041 are 16 independent files; with several contributors, split them across people.
- **US2 migration**: after T045, run T046, T047, T048, T049, T050 together.
- **US4**: T059, T060, T061, T062, T063, T064, T065 together.

## Implementation Strategy

- **MVP**: Phases 1 to 4 (US1 and US2), which are both P1: the tokens, the 12 components and 3 layouts, and the migrated, behavior-preserving idea-collector. Validate with quickstart scenarios 1, 2, 3, 7 and 8.
- **Suggested PR split** (each independently reviewable): PR A: Setup, Foundational (including the approved workflow tasks T018 and T019) and US1. PR A changes the root `package.json` and the lockfile, which `detect` treats as global, so its merge also triggers Terraform Apply for idea-collector and commifra: confirm both Terraform Plan checks report no changes before merging; PR B: US2 components; PR C: the idea-collector migration (T043 to T052); PR D: US3; PR E: US4 and Polish. The migration is the riskiest change, so keeping it separate keeps the behavior-preservation evidence easy to review.
- **Order within a story**: tests (confirm they fail), implementation, then the story checkpoint.
- **Gated**: T018 and T019 edit `.github/workflows/`, so they wait for explicit approval, and the first PR does not merge without them. Ask for that approval when implementation starts, so it does not block the first merge. Until it is given, the checks run locally through Nx, and the existing pipeline already lints and builds `idea-collector-frontend` when `packages/ui` changes.
- **Out of scope**: components beyond FR-014, a theme switcher control in the app, a custom brand palette or web font, reduced-motion support (not in the spec), and measuring SC-005.

## Requirement Traceability

| Requirement | Tasks |
| :--- | :--- |
| FR-001 design tokens and shared theme | T020-T025 |
| FR-002 Radix primitives | T030, T032, T033, T034, T035 |
| FR-003 interaction states | T026-T037 (every variant and state in the stories) |
| FR-004 light/dark, system default, override | T053-T058 |
| FR-005 WCAG AA contrast | T020, T023, T024, T056, T069 |
| FR-006 keyboard operability | T030, T059, T060, T061 |
| FR-007 responsive | T039-T041, T062, T063 |
| FR-008 central package consumed by apps | T001, T002, T006, T007, T044 |
| FR-009 no global style leakage | T021, T022, T024, T044, T051, T052 |
| FR-010 Storybook catalog | T009, T025, T026-T041 (stories), T069 |
| FR-011 layout primitives | T039, T040, T041 |
| FR-012 Lucide icons (and the Google logo exception) | T036, T038, T046-T050 |
| FR-013 migrate idea-collector, behavior preserved | T013-T017, T019, T043-T052 |
| FR-014 fixed first-release component set | T026-T037 |
| FR-015 axe over every story in both themes | T009, T011, T018, T056, T069 |
| FR-016 dismissible and non-dismissible dialogs | T030, T050 |
| SC-001 all screens use shared tokens and components | T051, T052 |
| SC-002 zero axe violations, both themes | T009, T018, T056, T069 |
| SC-003 theme change under 100 ms, no flash | T054-T058, quickstart scenario 5 |
| SC-004 no horizontal overflow 320-2560 px | T062, T063 |
| SC-005 30% faster view building | Not verified here (no baseline; see research T8) |
