# Implementation Plan: Consistent Design System and Shared UI Library

**Branch**: `feat/004` (spec: `004-design-system`) | **Date**: 2026-10-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-design-system/spec.md`

## Summary

Create a shared workspace package `@myspace/ui` (`packages/ui`) that provides the design tokens, a fixed first-release set of accessible components, three layout primitives, theme switching, and a Storybook catalog, then migrate every existing idea-collector screen onto it and delete the app's 636-line `App.css`.

The approach follows the clarified spec: Radix UI primitives styled with Tailwind CSS and semantic CSS variables (the shadcn/ui pattern), the stock shadcn neutral theme with the system font stack, `lucide-react` icons, and Storybook with its accessibility add-on (axe) as both the catalog and the automated accessibility gate.

Three things the spec does not settle are decided in [research.md](research.md) and need your attention:

1. The stock neutral theme does not meet WCAG 2.1 AA for form-control borders (FR-005), so the `--input` token is darker than stock and every foreground/background pair is checked by an automated contrast test.
2. The session-expired dialog must stay non-dismissible, so the dialog gets an explicit `dismissible` option. The spec has been amended to match (FR-016, User Story 2 scenarios 3 and 6).
3. A new package needs its own CI workflow (Principle III, `AGENTS.md`), and editing workflows needs your explicit approval. Two workflow edits are therefore gated tasks (T018 for the package, T019 to run the app's tests in CI) and they must ship in the first PR, with the package.

Behavior preservation (FR-013) is protected by characterization tests written against the current screens before they are changed, then run unchanged after the migration.

## Technical Context

**Language/Version**: TypeScript (the repo's pinned `~5.7.2`), React 19, Node 22 in CI (24 locally)

**Primary Dependencies**: Tailwind CSS 4.3 with `@tailwindcss/vite`; `radix-ui` 1.8 (unified package); `class-variance-authority`, `clsx`, `tailwind-merge`; `tw-animate-css`; `lucide-react` 1.x; Storybook 10.6 (`@storybook/react-vite`, `addon-a11y`, `addon-docs`, `addon-themes`, `addon-vitest`); Vitest 5 with `@vitest/browser-playwright`; Testing Library (`@testing-library/react` 16) with jsdom for the app tests; `culori` for the contrast test

**Storage**: Browser `localStorage` for the user's theme choice (key `ui-theme`); nothing server-side

**Testing**:
- Package: Vitest unit tests (token contrast, `cn`, theme logic) and Storybook-driven browser tests (axe accessibility in both themes, keyboard `play` tests, responsive overflow)
- App: Vitest + Testing Library characterization tests for the five existing screens
- Both run through Nx targets (`test`, `lint`, `typecheck`, `build`)

**Target Platform**: Evergreen browsers (Chrome, Firefox, Safari, Edge); no legacy browsers

**Project Type**: Shared frontend library (workspace package) plus migration of one existing web app

**Performance Goals**: Theme switch completes in under 100 ms with no unstyled flash (SC-003): CSS-variable swap, no color transitions, and a blocking inline script that sets the theme before first paint

**Constraints**:
- No global style leakage (FR-009): the shared theme file contains tokens and utilities only; Tailwind's base reset is opt-in per application
- Library is consumed from source inside the monorepo (no publish step)
- Existing legacy CSS variable names collide with shadcn token names and must be handled during the migration
- Modifying `.github/workflows/` requires explicit approval (`AGENTS.md`)
- The PR that introduces the package changes the root `package.json` and the lockfile, which the shared `detect` job treats as global: all pipelines run on the PR, and merging triggers Terraform Apply for idea-collector and commifra with no infrastructure change (see research D12)
- First release limited to the component set in FR-014

**Scale/Scope**: 1 package, 12 components, 3 layout primitives, 1 theme provider, 26 token pairs; 1 app migrated (5 components, 1 App shell, 636 lines of CSS removed)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against constitution v1.1.0.

- **I. AI-Native SDLC Pipeline**: PASS. Scope is exactly FR-001 to FR-015; the component set is fixed by FR-014, so no speculative components. Each PR carries intent, scope and verification steps.
- **II. Infrastructure as Code**: PASS (not applicable). No infrastructure or Terraform is touched.
- **III. Automated Quality & CI/CD Gates**: PASS, with a gate. `packages/ui` is a new package, so Principle III and `AGENTS.md` require its own CI workflow (lint, typecheck, test, build). Unlike the `scripts/` tooling in feature 003, a shared package is a "package" for this clause. Editing `.github/workflows/` needs explicit approval, so the workflow is a gated task (T018) that must land in the **same PR as the package**, not after it, and a second gated task (T019) adds a `Test Frontend` step to the existing idea-collector pull-request workflow, because that pipeline lints and builds the frontend but does not run tests. Until approval is given, checks run locally through Nx and the first PR does not merge.
- **IV. Strict Security & Credential Handling**: PASS. No secrets are introduced. The migration must not touch the tracked frontend `.env` or the Cognito values.
- **V. Codebase Respect & Localization**: PASS. Uses the existing eslint, TypeScript strictness and Nx conventions. The only deletion of existing code is `App.css`, which FR-013 requires.
- **VI. Branch Discipline & Naming**: PASS. Work happens on `feat/004`.

**Post-design re-check (after Phase 1)**: PASS. The one open gate is the CI-workflow approval under III. No Complexity Tracking entries are needed.

## Project Structure

### Documentation (this feature)

```text
specs/004-design-system/
├── plan.md              # This file
├── research.md          # Phase 0: decisions, rationale, alternatives, spec tensions
├── data-model.md        # Phase 1: token set, theme config, component model, state matrix
├── quickstart.md        # Phase 1: runnable validation scenarios
├── contracts/
│   ├── ui-package-api.md        # exports, component props, variants, accessibility behavior
│   ├── design-tokens.md         # token names, reference values, required contrast pairs
│   └── consumer-integration.md  # how an app adopts the library (CSS, Vite, HTML, theme)
├── checklists/
│   └── requirements.md  # Spec quality checklist (existing)
└── tasks.md             # Phase 2 output (/speckit-tasks - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
packages/ui/                              # NEW: @myspace/ui
├── package.json                          # exports point at TypeScript source (no build step)
├── project.json                          # Nx targets: lint, typecheck, test, storybook, build-storybook
├── tsconfig.json
├── eslint.config.js
├── vitest.config.ts                      # projects: unit (jsdom), browser (real browser tests), storybook (stories)
├── .storybook/
│   ├── main.ts                           # framework, addons
│   ├── preview.ts                        # theme decorator and toolbar, STORYBOOK_THEME, a11y test = 'error'
│   └── vitest.setup.ts
└── src/
    ├── index.ts                          # public API
    ├── styles/
    │   ├── theme.css                     # tokens, @theme mapping, dark variant (no base reset)
    │   ├── storybook.css                 # Storybook-only entry: layered Tailwind imports plus theme.css
    │   ├── theme-css.test.ts             # no element selectors, no reset, both modes defined
    │   └── theme-coexistence.browser.test.tsx   # plain HTML keeps identical computed styles
    ├── lib/
    │   ├── cn.ts                         # clsx + tailwind-merge
    │   └── cn.test.ts
    ├── theme/
    │   ├── ThemeProvider.tsx             # light | dark | system, persistence, class on <html>
    │   ├── useTheme.ts
    │   ├── theme-init.ts                 # blocking script source for index.html
    │   ├── theme.test.tsx                # unit tests for the provider and the init script
    │   └── theme.stories.tsx             # theme control with a rapid-toggle play test
    ├── tokens/
    │   ├── tokens.ts                     # token manifest (values and required pairs)
    │   ├── tokens.contrast.test.ts       # WCAG contrast check for every pair
    │   └── tokens.stories.tsx            # palette, type scale, spacing, radii, shadows
    ├── components/                       # one file per component plus its .stories.tsx
    │   ├── button.tsx          ├── input.tsx        ├── textarea.tsx
    │   ├── card.tsx            ├── dialog.tsx       ├── alert.tsx
    │   ├── select.tsx          ├── checkbox.tsx     ├── radio-group.tsx
    │   ├── tooltip.tsx         ├── spinner.tsx      ├── badge.tsx
    │   └── forced-colors.stories.tsx     # documents high-contrast (forced colors) behavior
    ├── layout/
    │   ├── page-container.tsx  ├── app-header.tsx   ├── sidebar-layout.tsx
    │   ├── edge-cases.stories.tsx        # under 320px, 200% text, long unbroken text
    │   └── layout.responsive.browser.test.tsx   # no horizontal overflow at 320-2560 px
    └── icons/google-icon.tsx             # brand logo (Lucide has no brand icons)

apps/idea-collector/frontend/             # MIGRATED (not a new project)
├── index.html                            # + theme-init blocking script
├── vite.config.ts                        # + @tailwindcss/vite
├── vitest.config.ts                      # NEW: jsdom, setup file, test include
├── package.json                          # + @myspace/ui (workspace), tailwindcss, vitest, Testing Library
├── project.json                          # + test target
└── src/
    ├── index.css                         # NEW: layered tailwind imports, @myspace/ui/theme.css, @source
    ├── App.tsx, main.tsx                 # use PageContainer, ThemeProvider
    ├── test/setup.ts                     # NEW: jest-dom matchers
    ├── components/*.tsx                  # Header, AuthPrompt, IdeaForm, IdeaList, SessionExpiredModal migrated
    ├── components/*.test.tsx             # characterization tests (written before the migration)
    ├── migration.test.ts                 # App.css gone, no raw color literals
    ├── theme-init-sync.test.ts           # index.html script matches the package's themeInitScript
    └── App.css                           # DELETED at the end of the migration

pnpm-workspace.yaml                       # + packages/*
package.json                              # workspaces gains packages/ui; no other change
.gitignore                                # + storybook-static/, *.tsbuildinfo
.github/workflows/ui.on_pull_request.yml  # GATED (T018): needs explicit approval (Principle III)
.github/workflows/idea-collector.on_pull_request.yml  # GATED (T019): + "Test Frontend" step
```

**Structure Decision**: One new workspace package under `packages/`, as the constitution designates for shared libraries, consumed from source so a change to a component is visible to the app immediately without a build or publish step. Components and their stories live side by side, one file per component, in the shadcn style so future components can be added with the same shape. The migration happens inside the existing `idea-collector-frontend` project; no new application is created. The two workflow edits are listed but gated, because they edit `.github/workflows/`.

## Complexity Tracking

No constitution violations to justify. The CI-workflow approval under Principle III is a gate, not a violation.
