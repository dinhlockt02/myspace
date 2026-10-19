import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect } from 'storybook/test'
import { CircleAlert, CircleCheck } from 'lucide-react'
import { Badge } from './badge'

const meta = {
  title: 'Components/Badge',
  component: Badge,
  args: { children: 'Badge' },
} satisfies Meta<typeof Badge>

export default meta
type Story = StoryObj<typeof meta>

const VARIANTS = ['default', 'secondary', 'outline', 'destructive'] as const

export const Variants: Story = {
  render: () => (
    <div className="flex flex-wrap items-center gap-3">
      {VARIANTS.map((variant) => (
        <Badge key={variant} variant={variant}>
          {variant}
        </Badge>
      ))}
    </div>
  ),
  // A badge is never an empty colored pill: every one has visible text or an aria-label
  play: async ({ canvasElement }) => {
    const badges = [...canvasElement.querySelectorAll<HTMLElement>('[data-slot="badge"]')]
    await expect(badges).toHaveLength(VARIANTS.length)
    for (const badge of badges) {
      await expect((badge.textContent ?? '').trim() || badge.getAttribute('aria-label')).toBeTruthy()
    }
  },
}

export const Counts: Story = {
  render: () => (
    <div className="flex items-center gap-3 text-sm">
      <span>Your Collection</span>
      <Badge variant="secondary">3 ideas</Badge>
    </div>
  ),
}

/** Meaning is carried by text and an icon, never by color alone */
export const Status: Story = {
  render: () => (
    <div className="flex flex-wrap items-center gap-3">
      <Badge variant="secondary">
        <CircleCheck aria-hidden="true" /> Saved
      </Badge>
      <Badge variant="destructive">
        <CircleAlert aria-hidden="true" /> Failed
      </Badge>
    </div>
  ),
  play: async ({ canvasElement }) => {
    const badges = [...canvasElement.querySelectorAll<HTMLElement>('[data-slot="badge"]')]
    const texts = badges.map((badge) => (badge.textContent ?? '').trim())
    // Each status has its own words, so removing the color (or seeing it as grayscale) loses nothing
    await expect(texts).toEqual(['Saved', 'Failed'])
    for (const badge of badges) {
      await expect(badge.querySelector('svg')).toHaveAttribute('aria-hidden', 'true')
    }
  },
}
