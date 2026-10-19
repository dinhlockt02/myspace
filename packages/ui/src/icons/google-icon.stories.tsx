import type { Meta, StoryObj } from '@storybook/react-vite'
import { GoogleIcon } from './google-icon'

const meta = {
  title: 'Icons/GoogleIcon',
  component: GoogleIcon,
} satisfies Meta<typeof GoogleIcon>

export default meta
type Story = StoryObj<typeof meta>

export const Sizes: Story = {
  render: () => (
    <div className="flex items-center gap-4">
      <GoogleIcon size={16} />
      <GoogleIcon />
      <GoogleIcon size={32} />
    </div>
  ),
}

/** Decorative by default: the button's text provides the accessible name */
export const InAButton: Story = {
  render: () => (
    <button
      type="button"
      className="inline-flex items-center gap-2 rounded-md border border-input bg-background px-4 py-2 text-sm font-medium text-foreground"
    >
      <GoogleIcon />
      Sign in with Google
    </button>
  ),
}
