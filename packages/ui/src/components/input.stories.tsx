import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, userEvent } from 'storybook/test'
import { Input } from './input'

const meta = {
  title: 'Components/Input',
  component: Input,
  args: { type: 'text' },
} satisfies Meta<typeof Input>

export default meta
type Story = StoryObj<typeof meta>

function Field({ id, label, children }: { id: string; label: string; children: React.ReactNode }) {
  return (
    <div className="grid max-w-sm gap-1.5">
      <label htmlFor={id} className="text-sm font-medium text-foreground">
        {label}
      </label>
      {children}
    </div>
  )
}

export const Default: Story = {
  render: (args) => (
    <Field id="email" label="Email">
      <Input {...args} id="email" placeholder="you@example.com" />
    </Field>
  ),
}

export const WithValue: Story = {
  render: (args) => (
    <Field id="name" label="Name">
      <Input {...args} id="name" defaultValue="Ada Lovelace" />
    </Field>
  ),
}

export const Disabled: Story = {
  render: (args) => (
    <Field id="disabled" label="Disabled field">
      <Input {...args} id="disabled" defaultValue="Cannot edit" disabled />
    </Field>
  ),
}

export const Invalid: Story = {
  render: (args) => (
    <Field id="invalid" label="Email">
      <Input {...args} id="invalid" defaultValue="not-an-email" invalid aria-describedby="invalid-message" />
      <p id="invalid-message" className="text-sm text-destructive">
        Enter a valid email address.
      </p>
    </Field>
  ),
  play: async ({ canvas }) => {
    const input = canvas.getByLabelText('Email')
    await expect(input).toHaveAttribute('aria-invalid', 'true')
    await expect(input).toHaveAccessibleDescription('Enter a valid email address.')
  },
}

/** Tab focuses the field and typing edits it */
export const Keyboard: Story = {
  render: (args) => (
    <Field id="typed" label="Email">
      <Input {...args} id="typed" />
    </Field>
  ),
  play: async ({ canvas }) => {
    const input = canvas.getByLabelText('Email')
    await userEvent.tab()
    await expect(input).toHaveFocus()
    await userEvent.keyboard('ada@example.com')
    await expect(input).toHaveValue('ada@example.com')
  },
}
