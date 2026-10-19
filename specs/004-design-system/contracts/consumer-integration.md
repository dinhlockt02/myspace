# Consumer Integration Contract

**Feature**: `004-design-system` | How an application adopts `@myspace/ui` (FR-001, FR-004, FR-008, FR-009, FR-013).

`apps/idea-collector/frontend` is the first adopter and follows this contract exactly. A future frontend does the same.

## 1. Dependencies

In the application's `package.json`:

- `"@myspace/ui": "workspace:*"`
- `tailwindcss` and `@tailwindcss/vite` (Tailwind 4.x)
- `lucide-react` if the application uses icons directly

`pnpm-workspace.yaml` must include `packages/*`. Nx derives the project dependency from `workspace:*`, so a change to `packages/ui` marks the application as affected.

## 2. Vite

Add the Tailwind plugin next to the React plugin:

```text
plugins: [react(), tailwindcss()]      // tailwindcss from '@tailwindcss/vite'
```

## 3. Stylesheet entry

One CSS entry file imported once from `main.tsx`, with this structure (order matters):

```text
@layer theme, base, components, utilities;
@import "tailwindcss/theme.css" layer(theme);      /* Tailwind theme layer */
@import "@myspace/ui/theme.css" layer(theme);      /* tokens, @theme mapping, dark variant */
@import "tailwindcss/utilities.css" layer(utilities);
@source "../../../../packages/ui/src";            /* so utilities used by the package are generated */
```

The base reset is **not** part of the shared theme (FR-009). An application adds it, as `@import "tailwindcss/preflight.css" layer(base);` between the theme and utilities imports, only when none of its remaining screens depend on browser-default or legacy styles. For idea-collector it is added at the end of the migration, once `App.css` is gone.

Use the layered form with `layer(...)`. Tailwind 4.3 also compiles the unlayered form (`@import "tailwindcss/theme"`), but then nothing is placed in a cascade layer, so the base reset competes with legacy CSS on specificity and source order. Inside `layer(base)` it always ranks below any unlayered legacy CSS, which is what keeps un-migrated views safe. If `@theme` inside a file imported with `layer(theme)` turns out not to work, import `@myspace/ui/theme.css` without `layer()` and record the finding in `research.md` D13.

## 4. HTML

In `index.html` `<head>`, before any stylesheet or script that renders:

```text
<script>/* contents of @myspace/ui/theme-init */</script>
```

This applies the stored or system theme before first paint, so there is no flash (SC-003). The `<html>` element must not carry a hard-coded theme class.

## 5. React root

Wrap the application once:

```text
<ThemeProvider defaultTheme="system">  <App />  </ThemeProvider>
```

A theme switcher control, if an application wants one, calls `useTheme().setTheme(...)`. The first release does not require adding a switcher to idea-collector; the capability and the system-preference default are what FR-004 requires.

## 6. Using the library

- Import components from `@myspace/ui`; never copy their source.
- Compose with `className`, merged through `cn`, for layout adjustments only. Color, radius and shadow come from tokens.
- Do not define raw colors, new color custom properties or element selectors in application CSS.

## 7. Migrating an existing application (FR-013)

Order for idea-collector:

1. Write characterization tests for the existing screens and confirm they pass on the current code.
2. Rename the application's legacy custom properties in `App.css` with a `--legacy-` prefix (they currently collide with `--primary`, `--danger`, `--radius-*`, `--font-sans` and others).
3. Add Tailwind, the stylesheet entry, the theme script and `ThemeProvider`.
4. Migrate screens one by one onto the library components (see the mapping in [data-model.md](../data-model.md)), running the characterization tests after each.
5. Delete `App.css` and its import.
6. Add the Tailwind base reset to the stylesheet entry (`@import "tailwindcss/preflight.css" layer(base);`).
7. Re-run the characterization tests and the quickstart checks.

Completion criteria: all characterization tests pass unchanged; no file in the application defines its own colors, spacing or typography outside the tokens; `App.css` no longer exists.

## 8. What consumers must not do

- Prefix or rename the shared tokens.
- Import component internals by path instead of the package entry.
- Override focus rings or remove `aria-*` attributes the components provide.
- Commit changes to the tracked `.env` as part of this work (constitution Principle IV).
