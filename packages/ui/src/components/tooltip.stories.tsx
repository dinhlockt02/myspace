import type { Meta, StoryObj } from '@storybook/react-vite'
import { Info } from 'lucide-react'
import { expect, screen, userEvent, waitFor } from 'storybook/test'
import { Button } from './button'
import { Tooltip, TooltipContent, TooltipTrigger } from './tooltip'

const meta = {
  title: 'Components/Tooltip',
  component: Tooltip,
  parameters: { layout: 'centered' },
} satisfies Meta<typeof Tooltip>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: (args) => (
    <Tooltip {...args}>
      <TooltipTrigger asChild>
        <Button type="button" variant="outline">
          Hover or focus me
        </Button>
      </TooltipTrigger>
      <TooltipContent>Extra detail that is also available elsewhere on the page</TooltipContent>
    </Tooltip>
  ),
}

/** The open state, so the accessibility check sees the tooltip. */
export const Open: Story = {
  render: (args) => (
    <div className="pt-16">
      <Tooltip {...args} defaultOpen>
        <TooltipTrigger asChild>
          <Button type="button" variant="outline">
            Open tooltip
          </Button>
        </TooltipTrigger>
        <TooltipContent>Saved on this device</TooltipContent>
      </Tooltip>
    </div>
  ),
}

export const OnAnIconButton: Story = {
  render: (args) => (
    <Tooltip {...args}>
      <TooltipTrigger asChild>
        <Button type="button" variant="ghost" size="icon" aria-label="About this field">
          <Info aria-hidden="true" />
        </Button>
      </TooltipTrigger>
      <TooltipContent>The name shown to other people</TooltipContent>
    </Tooltip>
  ),
}

/** Keyboard focus alone opens the tooltip, and Escape closes it while focus stays on the trigger */
export const Keyboard: Story = {
  render: (args) => (
    <Tooltip {...args}>
      <TooltipTrigger asChild>
        <Button type="button" variant="outline">
          Focus me
        </Button>
      </TooltipTrigger>
      <TooltipContent>Shown on keyboard focus</TooltipContent>
    </Tooltip>
  ),
  play: async ({ canvas }) => {
    const trigger = canvas.getByRole('button', { name: 'Focus me' })

    await userEvent.tab()
    await expect(trigger).toHaveFocus()
    await expect(await screen.findByRole('tooltip')).toHaveTextContent('Shown on keyboard focus')

    await userEvent.keyboard('{Escape}')
    await waitFor(() => expect(screen.queryByRole('tooltip')).not.toBeInTheDocument())
    await expect(trigger).toHaveFocus()
  },
}
