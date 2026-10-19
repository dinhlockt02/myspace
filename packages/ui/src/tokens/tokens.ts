/**
 * Design token manifest: the single source of truth for the color tokens, their values in both
 * modes, and the foreground/background pairs that must meet WCAG 2.1 AA.
 *
 * Values are the shadcn/ui neutral theme (oklch), adjusted where the stock value fails WCAG
 * (muted-foreground in light, input and ring) and extended with status colors. See
 * specs/004-design-system/contracts/design-tokens.md. `theme.css` mirrors these values;
 * theme-css.test.ts keeps the two in sync.
 */

export type Mode = 'light' | 'dark'
export type TokenGroup = 'surface' | 'text' | 'accent' | 'status' | 'control'

export interface Token {
  /** Unprefixed shadcn name, used as the CSS variable `--<name>` */
  name: string
  group: TokenGroup
  light: string
  dark: string
}

export interface ContrastPair {
  foreground: string
  background: string
  /** `text` needs 4.5:1; `control` (boundaries, focus rings) needs 3:1 */
  kind: 'text' | 'control'
}

/** Base radius; small, medium and large radii derive from it in theme.css */
export const radius = '0.625rem'

const t = (name: string, group: TokenGroup, light: string, dark: string): Token => ({
  name,
  group,
  light,
  dark,
})

export const colorTokens: Token[] = [
  t('background', 'surface', 'oklch(1 0 0)', 'oklch(0.145 0 0)'),
  t('foreground', 'text', 'oklch(0.145 0 0)', 'oklch(0.985 0 0)'),
  t('card', 'surface', 'oklch(1 0 0)', 'oklch(0.205 0 0)'),
  t('card-foreground', 'text', 'oklch(0.145 0 0)', 'oklch(0.985 0 0)'),
  t('popover', 'surface', 'oklch(1 0 0)', 'oklch(0.205 0 0)'),
  t('popover-foreground', 'text', 'oklch(0.145 0 0)', 'oklch(0.985 0 0)'),
  t('primary', 'accent', 'oklch(0.205 0 0)', 'oklch(0.922 0 0)'),
  t('primary-foreground', 'text', 'oklch(0.985 0 0)', 'oklch(0.205 0 0)'),
  t('secondary', 'accent', 'oklch(0.97 0 0)', 'oklch(0.269 0 0)'),
  t('secondary-foreground', 'text', 'oklch(0.205 0 0)', 'oklch(0.985 0 0)'),
  t('muted', 'surface', 'oklch(0.97 0 0)', 'oklch(0.269 0 0)'),
  // Adjusted: stock light 0.556 is 4.34:1 on muted
  t('muted-foreground', 'text', 'oklch(0.5 0 0)', 'oklch(0.708 0 0)'),
  t('accent', 'accent', 'oklch(0.97 0 0)', 'oklch(0.269 0 0)'),
  t('accent-foreground', 'text', 'oklch(0.205 0 0)', 'oklch(0.985 0 0)'),
  t('destructive', 'status', 'oklch(0.577 0.245 27.325)', 'oklch(0.704 0.191 22.216)'),
  t('destructive-foreground', 'text', 'oklch(0.985 0 0)', 'oklch(0.145 0 0)'),
  t('success', 'status', 'oklch(0.527 0.154 150.069)', 'oklch(0.723 0.219 149.579)'),
  t('success-foreground', 'text', 'oklch(0.985 0 0)', 'oklch(0.145 0 0)'),
  t('warning', 'status', 'oklch(0.555 0.163 48.4)', 'oklch(0.769 0.188 70.08)'),
  t('warning-foreground', 'text', 'oklch(0.985 0 0)', 'oklch(0.145 0 0)'),
  t('info', 'status', 'oklch(0.488 0.243 264.376)', 'oklch(0.707 0.165 254.624)'),
  t('info-foreground', 'text', 'oklch(0.985 0 0)', 'oklch(0.145 0 0)'),
  // Decorative separators only. Dark is an opaque approximation of the stock translucent value.
  t('border', 'control', 'oklch(0.922 0 0)', 'oklch(0.269 0 0)'),
  // Adjusted: the visible boundary of every form control needs 3:1 (WCAG 1.4.11)
  t('input', 'control', 'oklch(0.62 0 0)', 'oklch(0.58 0 0)'),
  // Adjusted: the focus indicator needs 3:1
  t('ring', 'control', 'oklch(0.62 0 0)', 'oklch(0.58 0 0)'),
]

const text = (foreground: string, background: string): ContrastPair => ({
  foreground,
  background,
  kind: 'text',
})
const control = (foreground: string, background: string): ContrastPair => ({
  foreground,
  background,
  kind: 'control',
})

/** The 26 pairs from contracts/design-tokens.md, checked in both modes */
export const contrastPairs: ContrastPair[] = [
  text('foreground', 'background'),
  text('card-foreground', 'card'),
  text('popover-foreground', 'popover'),
  text('primary-foreground', 'primary'),
  text('secondary-foreground', 'secondary'),
  text('muted-foreground', 'background'),
  text('muted-foreground', 'muted'),
  text('accent-foreground', 'accent'),
  text('destructive-foreground', 'destructive'),
  text('success-foreground', 'success'),
  text('warning-foreground', 'warning'),
  text('info-foreground', 'info'),
  text('destructive', 'background'),
  text('destructive', 'card'),
  text('success', 'background'),
  text('success', 'card'),
  text('warning', 'background'),
  text('warning', 'card'),
  text('info', 'background'),
  text('info', 'card'),
  control('input', 'background'),
  control('input', 'card'),
  control('input', 'popover'),
  control('ring', 'background'),
  control('ring', 'card'),
  control('ring', 'primary'),
]

/** Names of tokens that lack a value for a mode, as `name (mode)`. An empty list means complete. */
export function findMissingModes(tokens: Token[]): string[] {
  return tokens.flatMap((token) =>
    (['light', 'dark'] as const)
      .filter((mode) => !token[mode] || token[mode].trim() === '')
      .map((mode) => `${token.name} (${mode})`),
  )
}
