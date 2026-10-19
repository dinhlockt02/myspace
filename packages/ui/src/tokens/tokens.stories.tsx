import type { Meta, StoryObj } from '@storybook/react-vite'
import { colorTokens, contrastPairs, radius, type TokenGroup } from './tokens'

// Documentation stories for FR-001: every token is previewable in both modes.
const meta = {
  title: 'Foundations/Design tokens',
  parameters: { layout: 'padded' },
} satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const GROUP_TITLES: Record<TokenGroup, string> = {
  surface: 'Surfaces',
  text: 'Text',
  accent: 'Accents',
  status: 'Status',
  control: 'Controls and borders',
}

function Section({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  return (
    <section aria-labelledby={id} className="mb-10">
      <h2 id={id} className="mb-4 text-xl font-semibold text-foreground">
        {title}
      </h2>
      {children}
    </section>
  )
}

export const Colors: Story = {
  render: () => (
    <div>
      <p className="mb-6 max-w-prose text-sm text-muted-foreground">
        Semantic color tokens in the light and dark theme. Use the theme toolbar to switch the live
        swatches. {colorTokens.length} tokens, {contrastPairs.length} contrast pairs checked by the
        tests.
      </p>
      {(Object.keys(GROUP_TITLES) as TokenGroup[]).map((group) => (
        <Section key={group} id={`colors-${group}`} title={GROUP_TITLES[group]}>
          <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {colorTokens
              .filter((t) => t.group === group)
              .map((t) => (
                <li key={t.name} className="flex items-center gap-3">
                  <span
                    aria-hidden="true"
                    className="size-12 shrink-0 rounded-md border border-input"
                    style={{ background: `var(--${t.name})` }}
                  />
                  <span className="min-w-0 text-sm">
                    <span className="block font-medium text-foreground">--{t.name}</span>
                    <span className="block break-words text-muted-foreground">light {t.light}</span>
                    <span className="block break-words text-muted-foreground">dark {t.dark}</span>
                  </span>
                </li>
              ))}
          </ul>
        </Section>
      ))}
    </div>
  ),
}

const TYPE_SCALE = ['xs', 'sm', 'base', 'lg', 'xl', '2xl', '3xl', '4xl'] as const
const TYPE_CLASSES: Record<(typeof TYPE_SCALE)[number], string> = {
  xs: 'text-xs',
  sm: 'text-sm',
  base: 'text-base',
  lg: 'text-lg',
  xl: 'text-xl',
  '2xl': 'text-2xl',
  '3xl': 'text-3xl',
  '4xl': 'text-4xl',
}

export const Typography: Story = {
  render: () => (
    <Section id="type" title="Type scale (Tailwind theme, system font stack)">
      <ul className="space-y-3">
        {TYPE_SCALE.map((size) => (
          <li key={size} className="flex flex-wrap items-baseline gap-x-4">
            <span className="w-16 shrink-0 text-sm text-muted-foreground">text-{size}</span>
            <span className={`font-sans text-foreground ${TYPE_CLASSES[size]}`}>
              The quick brown fox jumps over the lazy dog
            </span>
          </li>
        ))}
      </ul>
    </Section>
  ),
}

const SPACING = [1, 2, 3, 4, 6, 8, 12, 16] as const

export const Spacing: Story = {
  render: () => (
    <Section id="spacing" title="Spacing scale (multiples of --spacing)">
      <ul className="space-y-2">
        {SPACING.map((n) => (
          <li key={n} className="flex items-center gap-4">
            <span className="w-24 shrink-0 text-sm text-muted-foreground">{n} × spacing</span>
            <span
              aria-hidden="true"
              className="h-3 rounded-sm bg-primary"
              style={{ width: `calc(var(--spacing) * ${n})` }}
            />
          </li>
        ))}
      </ul>
    </Section>
  ),
}

const RADII = [
  { name: 'rounded-sm', className: 'rounded-sm' },
  { name: 'rounded-md', className: 'rounded-md' },
  { name: 'rounded-lg', className: 'rounded-lg' },
  { name: 'rounded-xl', className: 'rounded-xl' },
]

const SHADOWS = [
  { name: 'shadow-xs', className: 'shadow-xs' },
  { name: 'shadow-sm', className: 'shadow-sm' },
  { name: 'shadow-md', className: 'shadow-md' },
  { name: 'shadow-lg', className: 'shadow-lg' },
]

export const RadiiAndShadows: Story = {
  render: () => (
    <div>
      <Section id="radii" title={`Radii (derived from --radius: ${radius})`}>
        <ul className="flex flex-wrap gap-6">
          {RADII.map((r) => (
            <li key={r.name} className="text-center text-sm text-muted-foreground">
              <span
                aria-hidden="true"
                className={`mb-2 block size-20 border border-input bg-card ${r.className}`}
              />
              {r.name}
            </li>
          ))}
        </ul>
      </Section>
      <Section id="shadows" title="Shadows and elevation (Tailwind theme)">
        <ul className="flex flex-wrap gap-6">
          {SHADOWS.map((s) => (
            <li key={s.name} className="text-center text-sm text-muted-foreground">
              <span
                aria-hidden="true"
                className={`mb-2 block size-20 rounded-md bg-card ${s.className}`}
              />
              {s.name}
            </li>
          ))}
        </ul>
      </Section>
    </div>
  ),
}
