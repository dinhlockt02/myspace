import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, fn, userEvent } from 'storybook/test'
import { ArrowRight, Pencil, Plus, Trash2 } from 'lucide-react'
import { Button } from './button'

const meta = {
  title: 'Components/Button',
  component: Button,
  args: { children: 'Button', type: 'button' },
} satisfies Meta<typeof Button>

export default meta
type Story = StoryObj<typeof meta>

const VARIANTS = ['default', 'secondary', 'outline', 'ghost', 'destructive', 'link'] as const
const SIZES = ['sm', 'default', 'lg'] as const

export const Variants: Story = {
  render: (args) => (
    <div className="flex flex-wrap items-center gap-3">
      {VARIANTS.map((variant) => (
        <Button key={variant} {...args} variant={variant}>
          {variant}
        </Button>
      ))}
    </div>
  ),
}

export const Sizes: Story = {
  render: (args) => (
    <div className="flex flex-wrap items-center gap-3">
      {SIZES.map((size) => (
        <Button key={size} {...args} size={size}>
          {size}
        </Button>
      ))}
      <Button {...args} size="icon" aria-label="Add item">
        <Plus aria-hidden="true" />
      </Button>
    </div>
  ),
}

export const Disabled: Story = {
  render: (args) => (
    <div className="flex flex-wrap items-center gap-3">
      {VARIANTS.map((variant) => (
        <Button key={variant} {...args} variant={variant} disabled>
          {variant}
        </Button>
      ))}
    </div>
  ),
}

export const WithIcon: Story = {
  render: (args) => (
    <div className="flex flex-wrap items-center gap-3">
      <Button {...args}>
        <Plus aria-hidden="true" /> New idea
      </Button>
      <Button {...args} variant="outline">
        Continue <ArrowRight aria-hidden="true" />
      </Button>
    </div>
  ),
}

export const AsLink: Story = {
  render: () => (
    <Button asChild variant="outline">
      <a href="#docs">Read the docs</a>
    </Button>
  ),
}

/** The focus ring is visible against the page (3:1, see the design tokens contract) */
export const Focused: Story = {
  args: { children: 'Focused button' },
  play: async ({ canvas }) => {
    const button = canvas.getByRole('button', { name: 'Focused button' })
    button.focus()
    await expect(button).toHaveFocus()
  },
}

/** Tab reaches enabled buttons and skips disabled ones; Enter and Space both activate (FR-006) */
export const Keyboard: Story = {
  args: { onClick: fn() },
  render: (args) => (
    <div className="flex flex-wrap items-center gap-3">
      <Button {...args}>First</Button>
      <Button {...args} disabled>
        Skipped
      </Button>
      <Button {...args}>Last</Button>
    </div>
  ),
  play: async ({ canvas, args }) => {
    await userEvent.tab()
    await expect(canvas.getByRole('button', { name: 'First' })).toHaveFocus()

    await userEvent.keyboard('{Enter}')
    await expect(args.onClick).toHaveBeenCalledTimes(1)
    await userEvent.keyboard(' ')
    await expect(args.onClick).toHaveBeenCalledTimes(2)

    await userEvent.tab()
    await expect(canvas.getByRole('button', { name: 'Last' })).toHaveFocus()
    await expect(canvas.getByRole('button', { name: 'Skipped' })).not.toHaveFocus()

    await userEvent.keyboard('{Enter}')
    await expect(args.onClick).toHaveBeenCalledTimes(3)
  },
}

/** Icon-only buttons: the type requires `aria-label` or `aria-labelledby`, and each one has an accessible name */
export const IconOnly: Story = {
  render: (args) => (
    <div className="flex items-center gap-3">
      <Button {...args} size="icon" variant="outline" aria-label="Add idea">
        <Plus aria-hidden="true" />
      </Button>
      <Button {...args} size="icon" variant="outline" aria-label="Edit idea">
        <Pencil aria-hidden="true" />
      </Button>
      <Button {...args} size="icon" variant="destructive" aria-label="Delete idea">
        <Trash2 aria-hidden="true" />
      </Button>
    </div>
  ),
  play: async ({ canvas }) => {
    const buttons = canvas.getAllByRole('button')
    await expect(buttons).toHaveLength(3)
    for (const name of ['Add idea', 'Edit idea', 'Delete idea']) {
      await expect(canvas.getByRole('button', { name })).toBeInTheDocument()
    }
    for (const button of buttons) {
      await expect(button).toHaveAccessibleName()
      // Nothing but the icon inside, and the icon is hidden from assistive technology
      await expect(button).toHaveTextContent('')
      await expect(button.querySelector('svg')).toHaveAttribute('aria-hidden', 'true')
    }
  },
}
