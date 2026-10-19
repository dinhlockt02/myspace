import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, screen, userEvent, waitFor } from 'storybook/test'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './select'

const meta = {
  title: 'Components/Select',
  component: Select,
  parameters: { layout: 'padded' },
} satisfies Meta<typeof Select>

export default meta
type Story = StoryObj<typeof meta>

function Field({ id, label, children }: { id: string; label: string; children: React.ReactNode }) {
  return (
    <div className="grid w-64 gap-1.5">
      <label htmlFor={id} className="text-sm font-medium text-foreground">
        {label}
      </label>
      {children}
    </div>
  )
}

const Items = () => (
  <SelectContent>
    <SelectItem value="light">Light</SelectItem>
    <SelectItem value="dark">Dark</SelectItem>
    <SelectItem value="system">System</SelectItem>
  </SelectContent>
)

export const Default: Story = {
  render: (args) => (
    <Field id="theme" label="Theme">
      <Select {...args}>
        <SelectTrigger id="theme">
          <SelectValue placeholder="Choose a theme" />
        </SelectTrigger>
        <Items />
      </Select>
    </Field>
  ),
}

export const WithValue: Story = {
  render: (args) => (
    <Field id="theme-value" label="Theme">
      <Select {...args} defaultValue="dark">
        <SelectTrigger id="theme-value">
          <SelectValue />
        </SelectTrigger>
        <Items />
      </Select>
    </Field>
  ),
}

export const Disabled: Story = {
  render: (args) => (
    <Field id="theme-disabled" label="Theme (disabled)">
      <Select {...args} disabled>
        <SelectTrigger id="theme-disabled">
          <SelectValue placeholder="Choose a theme" />
        </SelectTrigger>
        <Items />
      </Select>
    </Field>
  ),
}

export const Invalid: Story = {
  render: (args) => (
    <Field id="theme-invalid" label="Theme">
      <Select {...args}>
        <SelectTrigger id="theme-invalid" invalid aria-describedby="theme-invalid-message">
          <SelectValue placeholder="Choose a theme" />
        </SelectTrigger>
        <Items />
      </Select>
      <p id="theme-invalid-message" className="text-sm text-destructive">
        Choose a theme to continue.
      </p>
    </Field>
  ),
}

/**
 * The open state, so the accessibility check sees the listbox.
 *
 * Only `aria-hidden-focus` is switched off here. While a modal listbox is open Radix hides the rest
 * of the page from assistive technology and traps keyboard focus inside the listbox, so the
 * trigger in the hidden subtree cannot be reached; axe still reports it as focusable. Every other
 * rule still applies to the listbox and the page.
 */
export const Open: Story = {
  parameters: {
    a11y: { config: { rules: [{ id: 'aria-hidden-focus', enabled: false }] } },
  },
  render: (args) => (
    <Field id="theme-open" label="Theme">
      <Select {...args} defaultOpen defaultValue="system">
        <SelectTrigger id="theme-open">
          <SelectValue />
        </SelectTrigger>
        <Items />
      </Select>
    </Field>
  ),
}

/** Arrows move, Enter or Space select, Escape closes, typing jumps to a match, and focus returns to the trigger */
export const Keyboard: Story = {
  render: (args) => (
    <Field id="theme-keys" label="Theme">
      <Select {...args}>
        <SelectTrigger id="theme-keys">
          <SelectValue placeholder="Choose a theme" />
        </SelectTrigger>
        <Items />
      </Select>
    </Field>
  ),
  play: async ({ canvas }) => {
    const trigger = canvas.getByRole('combobox', { name: 'Theme' })
    const closed = () => waitFor(() => expect(screen.queryByRole('listbox')).not.toBeInTheDocument())
    const option = (name: string) => screen.getByRole('option', { name })

    await userEvent.tab()
    await expect(trigger).toHaveFocus()

    // ArrowDown opens; the first option takes focus, ArrowDown moves, Enter selects
    await userEvent.keyboard('{ArrowDown}')
    await screen.findByRole('listbox')
    await waitFor(() => expect(option('Light')).toHaveFocus())
    await userEvent.keyboard('{ArrowDown}')
    await waitFor(() => expect(option('Dark')).toHaveFocus())
    await userEvent.keyboard('{Enter}')
    await closed()
    await expect(trigger).toHaveTextContent('Dark')
    await expect(trigger).toHaveFocus()

    // Space opens on the selected option, ArrowDown moves, Space selects
    await userEvent.keyboard(' ')
    await screen.findByRole('listbox')
    await waitFor(() => expect(option('Dark')).toHaveFocus())
    await userEvent.keyboard('{ArrowDown}')
    await waitFor(() => expect(option('System')).toHaveFocus())
    await userEvent.keyboard(' ')
    await closed()
    await expect(trigger).toHaveTextContent('System')

    // Escape closes without changing the value
    await userEvent.keyboard('{Enter}')
    await screen.findByRole('listbox')
    await userEvent.keyboard('{ArrowUp}')
    await userEvent.keyboard('{Escape}')
    await closed()
    await expect(trigger).toHaveTextContent('System')
    await expect(trigger).toHaveFocus()

    // Type-ahead jumps to the matching option
    await userEvent.keyboard('{Enter}')
    await screen.findByRole('listbox')
    await userEvent.keyboard('l')
    await waitFor(() => expect(option('Light')).toHaveFocus())
    await userEvent.keyboard('{Enter}')
    await closed()
    await expect(trigger).toHaveTextContent('Light')
  },
}
