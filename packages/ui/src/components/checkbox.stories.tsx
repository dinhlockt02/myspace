import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, userEvent } from 'storybook/test'
import { Checkbox } from './checkbox'

const meta = {
  title: 'Components/Checkbox',
  component: Checkbox,
} satisfies Meta<typeof Checkbox>

export default meta
type Story = StoryObj<typeof meta>

function Labelled({ id, label, ...props }: { id: string; label: string } & React.ComponentProps<typeof Checkbox>) {
  return (
    <div className="flex items-center gap-2">
      <Checkbox id={id} {...props} />
      <label htmlFor={id} className="text-sm text-foreground">
        {label}
      </label>
    </div>
  )
}

export const States: Story = {
  render: () => (
    <div className="grid gap-3">
      <Labelled id="unchecked" label="Unchecked" />
      <Labelled id="checked" label="Checked" defaultChecked />
      <Labelled id="indeterminate" label="Indeterminate" checked="indeterminate" />
      <Labelled id="disabled" label="Disabled" disabled />
      <Labelled id="disabled-checked" label="Disabled and checked" disabled defaultChecked />
    </div>
  ),
}

export const Invalid: Story = {
  render: () => (
    <div className="grid gap-1.5">
      <Labelled id="terms" label="I accept the terms" invalid aria-describedby="terms-message" />
      <p id="terms-message" className="text-sm text-destructive">
        You must accept the terms to continue.
      </p>
    </div>
  ),
}

/** Tab focuses the checkbox and Space toggles it; a disabled checkbox is skipped */
export const Keyboard: Story = {
  render: () => (
    <div className="grid gap-3">
      <Labelled id="k-first" label="Subscribe" />
      <Labelled id="k-disabled" label="Unavailable" disabled />
      <Labelled id="k-last" label="Remember me" />
    </div>
  ),
  play: async ({ canvas }) => {
    const first = canvas.getByRole('checkbox', { name: 'Subscribe' })

    await userEvent.tab()
    await expect(first).toHaveFocus()
    await expect(first).not.toBeChecked()
    await userEvent.keyboard(' ')
    await expect(first).toBeChecked()
    await userEvent.keyboard(' ')
    await expect(first).not.toBeChecked()

    await userEvent.tab()
    await expect(canvas.getByRole('checkbox', { name: 'Unavailable' })).not.toHaveFocus()
    await expect(canvas.getByRole('checkbox', { name: 'Remember me' })).toHaveFocus()
  },
}
