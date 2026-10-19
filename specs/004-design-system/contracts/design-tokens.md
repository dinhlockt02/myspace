# Design Tokens Contract

**Feature**: `004-design-system` | Source of truth for `packages/ui/src/tokens/tokens.ts` and `packages/ui/src/styles/theme.css` (FR-001, FR-005).

## Naming and mechanism

- Tokens are CSS custom properties with the standard, **unprefixed** shadcn names, defined under `:root` (light) and `.dark` (dark).
- `@theme inline` in `theme.css` maps each token to a Tailwind utility (`bg-background`, `text-muted-foreground`, `border-input`, `ring-ring`, and so on), so components never use raw colors.
- Values are `oklch`. Typography is the Tailwind system font stack and type scale; spacing is the Tailwind spacing scale; neither is redefined.
- `theme.css` contains tokens, the `@theme inline` mapping and the dark variant declaration only. It has **no** element selectors, **no** base reset (FR-009) and no animations (those are in `animate.css`).

## Reference values

These are the stock shadcn neutral theme values, adjusted where the stock value fails WCAG 2.1 AA (marked **adjusted**) and extended with status colors (marked **added**). Contrast ratios were measured with `culori` on 2026-10-19. The first implementation task regenerates the stock values from the shadcn CLI and re-runs the contrast test; the test, not this table, is authoritative.

| Token | Light | Dark | Note |
| :--- | :--- | :--- | :--- |
| `background` | `oklch(1 0 0)` | `oklch(0.145 0 0)` | |
| `foreground` | `oklch(0.145 0 0)` | `oklch(0.985 0 0)` | |
| `card` / `popover` | `oklch(1 0 0)` | `oklch(0.205 0 0)` | |
| `card-foreground` / `popover-foreground` | `oklch(0.145 0 0)` | `oklch(0.985 0 0)` | |
| `primary` | `oklch(0.205 0 0)` | `oklch(0.922 0 0)` | |
| `primary-foreground` | `oklch(0.985 0 0)` | `oklch(0.205 0 0)` | |
| `secondary` / `muted` / `accent` | `oklch(0.97 0 0)` | `oklch(0.269 0 0)` | |
| `secondary-foreground` / `accent-foreground` | `oklch(0.205 0 0)` | `oklch(0.985 0 0)` | |
| `muted-foreground` | `oklch(0.5 0 0)` | `oklch(0.708 0 0)` | **adjusted** (stock light `0.556` is 4.34:1 on `muted`) |
| `destructive` | `oklch(0.577 0.245 27.325)` | `oklch(0.704 0.191 22.216)` | |
| `destructive-foreground` | `oklch(0.985 0 0)` | `oklch(0.145 0 0)` | **added** |
| `success` | `oklch(0.527 0.154 150.069)` | `oklch(0.723 0.219 149.579)` | **added** |
| `warning` | `oklch(0.555 0.163 48.4)` | `oklch(0.769 0.188 70.08)` | **added** |
| `info` | `oklch(0.488 0.243 264.376)` | `oklch(0.707 0.165 254.624)` | **added** |
| `success-foreground` / `warning-foreground` | `oklch(0.985 0 0)` | `oklch(0.145 0 0)` | **added** |
| `info-foreground` | `oklch(0.985 0 0)` | `oklch(0.145 0 0)` | **added** |
| `border` | `oklch(0.922 0 0)` | `oklch(0.269 0 0)` | Decorative separators only |
| `input` | `oklch(0.62 0 0)` | `oklch(0.58 0 0)` | **adjusted** (stock `0.922` is 1.26:1; WCAG 1.4.11 needs 3:1). The visible boundary of every form control |
| `ring` | `oklch(0.62 0 0)` | `oklch(0.58 0 0)` | **adjusted** (stock light `0.708` is 2.59:1). Focus indicator |
| `radius` | `0.625rem` | same | Small, medium, large radii derive from it |

Components use `border-input` for control boundaries and `bg-background` or `bg-card` for fills. They do not use the stock dark-mode tinted input fill, because that would hide the boundary.

## Required contrast pairs

Evaluated in both modes by `tokens.contrast.test.ts`. A pair fails the build below its threshold. Measured ratios for the reference values above:

| Threshold | Pair (foreground on background) | Light | Dark |
| :--- | :--- | :--- | :--- |
| text 4.5 | `foreground` on `background` | 19.79 | 18.96 |
| text 4.5 | `card-foreground` on `card` | 19.79 | 17.16 |
| text 4.5 | `popover-foreground` on `popover` | 19.79 | 17.16 |
| text 4.5 | `primary-foreground` on `primary` | 17.16 | 14.22 |
| text 4.5 | `secondary-foreground` on `secondary` | 16.42 | 14.48 |
| text 4.5 | `muted-foreground` on `background` | 6.00 | 7.63 |
| text 4.5 | `muted-foreground` on `muted` | 5.50 | 5.83 |
| text 4.5 | `accent-foreground` on `accent` | 16.42 | 14.48 |
| text 4.5 | `destructive-foreground` on `destructive` | 4.71 | 6.89 |
| text 4.5 | `success-foreground` on `success` | 4.78 | 8.78 |
| text 4.5 | `warning-foreground` on `warning` | 4.86 | 9.17 |
| text 4.5 | `info-foreground` on `info` | 6.54 | 7.57 |
| text 4.5 | `destructive` on `background` | 4.91 | 6.89 |
| text 4.5 | `destructive` on `card` | 4.91 | 6.24 |
| text 4.5 | `success` on `background` | 4.99 | 8.78 |
| text 4.5 | `success` on `card` | 4.99 | 7.94 |
| text 4.5 | `warning` on `background` | 5.07 | 9.17 |
| text 4.5 | `warning` on `card` | 5.07 | 8.30 |
| text 4.5 | `info` on `background` | 6.82 | 7.57 |
| text 4.5 | `info` on `card` | 6.82 | 6.85 |
| control 3 | `input` on `background` | 3.64 | 4.62 |
| control 3 | `input` on `card` | 3.64 | 4.18 |
| control 3 | `input` on `popover` | 3.64 | 4.18 |
| control 3 | `ring` on `background` | 3.64 | 4.62 |
| control 3 | `ring` on `card` | 3.64 | 4.18 |
| control 3 | `ring` on `primary` | 4.92 | 3.40 |

26 pairs, 0 failing for the reference values.

The test covers tokens. It does not replace the Storybook axe run, which checks the rendered components (for example text on a tinted background that no single token pair describes).

## Change rules

- Adding or changing a token requires updating `tokens.ts`, both modes, and its pairs in the same change.
- A token without both modes, or a pair below threshold, fails the `test` target.
- Prefixing or renaming tokens is a breaking change for every consumer and for the shadcn tooling; it needs a spec amendment.
