# @myspace/ui

The shared design system for the monorepo: design tokens, accessible React components and layout
primitives, with light and dark themes. `apps/idea-collector/frontend` is the first consumer.

Stack: React 19, Tailwind CSS 4, [Radix UI](https://www.radix-ui.com) primitives, `class-variance-authority`,
`lucide-react` icons, Storybook 10 and Vitest 5.

## What is in the package

| Path | Contents |
| :--- | :--- |
| `src/tokens/` | The color tokens (`tokens.ts`), their WCAG contrast pairs and the contrast test |
| `src/styles/` | `theme.css` (tokens, Tailwind mapping, dark variant), `animate.css` (enter and exit animations), Storybook-only CSS |
| `src/components/` | Button, Input, Textarea, Select, Checkbox, RadioGroup, Card, Dialog, Alert, Tooltip, Badge, Spinner |
| `src/layout/` | `PageContainer`, `AppHeader`, `SidebarLayout` |
| `src/theme/` | `ThemeProvider`, `useTheme` and `themeInitScript` (no-flash theme before first paint) |
| `src/icons/` | `GoogleIcon` (the brand logo, which `lucide-react` does not ship) |
| `src/index.ts` | The public API. Import from `@myspace/ui`, never from a component's path |

Consumers adopt the package by following
[contracts/consumer-integration.md](../../specs/004-design-system/contracts/consumer-integration.md).
The public API is listed in
[contracts/ui-package-api.md](../../specs/004-design-system/contracts/ui-package-api.md).

## Running it

Run everything through Nx from the repository root:

```bash
pnpm nx run ui:storybook         # the component catalog at http://localhost:6006, with a light/dark toolbar
pnpm nx run ui:build-storybook   # the static catalog (packages/ui/storybook-static)
pnpm nx run ui:lint
pnpm nx run ui:typecheck
pnpm nx run ui:test
```

`ui:test` runs three Vitest projects, which you can select with `-- --project <name>`:

| Project | Runs in | Covers |
| :--- | :--- | :--- |
| `unit` | jsdom | Token contrast and completeness, `theme.css` rules, `cn`, `ThemeProvider`, the theme init script |
| `browser` | Chromium | Tests that need real layout or computed styles: coexistence with plain HTML, responsive overflow from 320px to 2560px, forced colors |
| `storybook` | Chromium | Every story: axe accessibility checks (any violation fails) and the keyboard `play` tests |

The browser projects need Playwright's Chromium once per machine:

```bash
pnpm exec playwright install --with-deps chromium
```

Run the Storybook project once per theme. `STORYBOOK_THEME` picks the initial theme, and `ui:test` is
not cached because Nx does not hash environment variables:

```bash
STORYBOOK_THEME=light pnpm nx run ui:test -- --project storybook
STORYBOOK_THEME=dark  pnpm nx run ui:test -- --project storybook
```

CI does the same in `.github/workflows/ui.on_pull_request.yml`.

## Tokens and the contrast test

Tokens are CSS custom properties with the standard shadcn names (`--background`, `--primary`,
`--muted-foreground`, and so on), defined for light under `:root` and for dark under `.dark` in
`src/styles/theme.css`, and mapped to Tailwind utilities (`bg-background`, `text-muted-foreground`,
`border-input`). Components use these utilities and never raw colors.

`src/tokens/tokens.ts` lists every token with both values and the foreground and background pairs that
must stay readable. `tokens.contrast.test.ts` measures each pair with `culori` in both modes and fails
below WCAG 2.1 AA (4.5:1 for text, 3:1 for control boundaries and focus rings). To change a color:

1. Edit the value in `tokens.ts` and in `theme.css`, for both modes.
2. If you add a token, add its pairs to `contrastPairs`.
3. Run `pnpm nx run ui:test -- --project unit`. A token missing a mode, or a pair under its threshold, fails.

The full rules are in
[contracts/design-tokens.md](../../specs/004-design-system/contracts/design-tokens.md). `theme.css`
deliberately has no element selectors and no base reset, so adding it to a page with older CSS changes
nothing (an application opts in to Tailwind's reset itself).

## Themes

Wrap an application in `ThemeProvider` and call `useTheme()` for `{ theme, resolvedTheme, setTheme }`.
The value is `light`, `dark` or `system` (the default, following the operating system) and is stored in
`localStorage` under `ui-theme`. Inline `themeInitScript` in `<head>` so the stored or system theme is
applied before the first paint.

## Adding a component

Follow the shape of the existing ones, for example `src/components/textarea.tsx`:

1. Create `src/components/<name>.tsx`. Build on a Radix primitive when the behavior is non-trivial.
   Give the root element a `data-slot`, accept and merge `className` through `cn`, and forward the
   rest of the element's props.
2. Style with token utilities only. Put variants in `cva`; if you export the variants helper, put it in
   its own file (see `button-variants.ts`) so Fast Refresh keeps working.
3. Cover the states: hover, focus, disabled, invalid. Use `focus-visible:ring-*` with `forcedColorsFocus`
   from `src/lib/forced-colors.ts` so the focus indicator survives forced colors mode.
4. Keep it accessible: an icon-only control must take `aria-label` or `aria-labelledby` (see how `Button`
   types this), decorative icons get `aria-hidden`, and labels must be able to wrap.
5. Add `src/components/<name>.stories.tsx` with a story per variant and state, plus a `play` function for
   keyboard behavior. The Storybook project runs axe on every story, in both themes.
6. Export it from `src/index.ts`.
7. Run `pnpm nx run-many -t lint,typecheck,test -p ui` and both Storybook themes before opening a pull request.
