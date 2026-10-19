import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, userEvent } from 'storybook/test'
import { Textarea } from './textarea'

const meta = {
  title: 'Components/Textarea',
  component: Textarea,
} satisfies Meta<typeof Textarea>

export default meta
type Story = StoryObj<typeof meta>

function Field({ id, label, children }: { id: string; label: string; children: React.ReactNode }) {
  return (
    <div className="grid max-w-md gap-1.5">
      <label htmlFor={id} className="text-sm font-medium text-foreground">
        {label}
      </label>
      {children}
    </div>
  )
}

export const Default: Story = {
  render: (args) => (
    <Field id="idea" label="Your idea">
      <Textarea {...args} id="idea" rows={4} placeholder="Type your idea here" />
    </Field>
  ),
}

export const WithValue: Story = {
  render: (args) => (
    <Field id="filled" label="Notes">
      <Textarea {...args} id="filled" rows={3} defaultValue="A thought worth keeping." />
    </Field>
  ),
}

export const Disabled: Story = {
  render: (args) => (
    <Field id="disabled" label="Disabled notes">
      <Textarea {...args} id="disabled" rows={3} defaultValue="Read only for now" disabled />
    </Field>
  ),
}

export const Invalid: Story = {
  render: (args) => (
    <Field id="invalid" label="Your idea">
      <Textarea {...args} id="invalid" rows={3} invalid aria-describedby="invalid-message" />
      <p id="invalid-message" className="text-sm text-destructive">
        An idea cannot be empty.
      </p>
    </Field>
  ),
  play: async ({ canvas }) => {
    const textarea = canvas.getByLabelText('Your idea')
    await expect(textarea).toHaveAttribute('aria-invalid', 'true')
    await expect(textarea).toHaveAccessibleDescription('An idea cannot be empty.')
  },
}

/** Tab focuses the field, typing edits it and Enter adds a line instead of leaving the field */
export const Keyboard: Story = {
  render: (args) => (
    <Field id="typed" label="Your idea">
      <Textarea {...args} id="typed" rows={3} />
    </Field>
  ),
  play: async ({ canvas }) => {
    const textarea = canvas.getByLabelText('Your idea')
    await userEvent.tab()
    await expect(textarea).toHaveFocus()
    await userEvent.keyboard('First line{Enter}Second line')
    await expect(textarea).toHaveValue('First line\nSecond line')
    await expect(textarea).toHaveFocus()
  },
}
