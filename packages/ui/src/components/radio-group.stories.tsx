import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, userEvent, waitFor } from 'storybook/test'
import { RadioGroup, RadioGroupItem } from './radio-group'

const meta = {
  title: 'Components/RadioGroup',
  component: RadioGroup,
} satisfies Meta<typeof RadioGroup>

export default meta
type Story = StoryObj<typeof meta>

function Option({ id, value, label, disabled }: { id: string; value: string; label: string; disabled?: boolean }) {
  return (
    <div className="flex items-center gap-2">
      <RadioGroupItem id={id} value={value} disabled={disabled} />
      <label htmlFor={id} className="text-sm text-foreground">
        {label}
      </label>
    </div>
  )
}

export const Default: Story = {
  render: (args) => (
    <fieldset className="grid gap-3">
      <legend className="mb-2 text-sm font-medium text-foreground">Theme</legend>
      <RadioGroup {...args} defaultValue="system" aria-label="Theme">
        <Option id="r-light" value="light" label="Light" />
        <Option id="r-dark" value="dark" label="Dark" />
        <Option id="r-system" value="system" label="System" />
      </RadioGroup>
    </fieldset>
  ),
}

export const DisabledOption: Story = {
  render: (args) => (
    <RadioGroup {...args} defaultValue="a" aria-label="Plan">
      <Option id="p-a" value="a" label="Free" />
      <Option id="p-b" value="b" label="Team" />
      <Option id="p-c" value="c" label="Enterprise (unavailable)" disabled />
    </RadioGroup>
  ),
}

export const Invalid: Story = {
  render: (args) => (
    <div className="grid gap-1.5">
      <RadioGroup {...args} invalid aria-label="Contact preference" aria-describedby="contact-message">
        <Option id="c-email" value="email" label="Email" />
        <Option id="c-phone" value="phone" label="Phone" />
      </RadioGroup>
      <p id="contact-message" className="text-sm text-destructive">
        Choose how we should contact you.
      </p>
    </div>
  ),
}

/** Tab enters the group on the selected radio, arrows move and select (wrapping), Tab leaves the group */
export const Keyboard: Story = {
  render: (args) => (
    <div className="grid gap-3">
      <RadioGroup {...args} defaultValue="light" aria-label="Theme">
        <Option id="k-light" value="light" label="Light" />
        <Option id="k-dark" value="dark" label="Dark" />
        <Option id="k-system" value="system" label="System" />
      </RadioGroup>
      <button type="button" className="w-fit text-sm text-foreground underline">
        After the group
      </button>
    </div>
  ),
  play: async ({ canvas }) => {
    const radio = (name: string) => canvas.getByRole('radio', { name })
    const checked = (name: string) => waitFor(() => expect(radio(name)).toBeChecked())
    const focused = (name: string) => waitFor(() => expect(radio(name)).toHaveFocus())
    // Radix moves focus on the next tick and selects the radio only while the arrow key is still down.
    // user-event's `{ArrowDown}` releases it in the same tick, which no real key press does, so hold the key.
    const arrow = async (key: 'ArrowDown' | 'ArrowUp', expected: string) => {
      await userEvent.keyboard(`{${key}>}`)
      await focused(expected)
      await checked(expected)
      await userEvent.keyboard(`{/${key}}`)
    }

    await userEvent.tab()
    await focused('Light')
    await checked('Light')

    await arrow('ArrowDown', 'Dark')
    await arrow('ArrowDown', 'System')
    // Wraps around from the last option
    await arrow('ArrowDown', 'Light')
    await arrow('ArrowUp', 'System')

    // The group is a single tab stop
    await userEvent.tab()
    await expect(canvas.getByRole('button', { name: 'After the group' })).toHaveFocus()
  },
}
