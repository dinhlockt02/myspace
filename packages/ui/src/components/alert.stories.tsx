import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect } from 'storybook/test'
import { CircleAlert, CircleCheck, Info, TriangleAlert } from 'lucide-react'
import { Alert, AlertDescription, AlertTitle } from './alert'

const meta = {
  title: 'Components/Alert',
  component: Alert,
} satisfies Meta<typeof Alert>

export default meta
type Story = StoryObj<typeof meta>

export const Variants: Story = {
  render: () => (
    <div className="grid max-w-xl gap-4">
      <Alert>
        <Info aria-hidden="true" />
        <AlertTitle>Heads up</AlertTitle>
        <AlertDescription>A neutral message with a title and a description.</AlertDescription>
      </Alert>
      <Alert variant="info">
        <Info aria-hidden="true" />
        <AlertTitle>Information</AlertTitle>
        <AlertDescription>Your draft is saved automatically on this device.</AlertDescription>
      </Alert>
      <Alert variant="success">
        <CircleCheck aria-hidden="true" />
        <AlertTitle>Saved</AlertTitle>
        <AlertDescription>Your idea has been recorded securely.</AlertDescription>
      </Alert>
      <Alert variant="warning">
        <TriangleAlert aria-hidden="true" />
        <AlertTitle>Careful</AlertTitle>
        <AlertDescription>Your session ends after one hour of inactivity.</AlertDescription>
      </Alert>
      <Alert variant="destructive">
        <CircleAlert aria-hidden="true" />
        <AlertTitle>Could not save</AlertTitle>
        <AlertDescription>Check your connection and try again.</AlertDescription>
      </Alert>
    </div>
  ),
  // Urgent variants interrupt with role="alert"; the others are polite role="status" updates
  play: async ({ canvas }) => {
    const text = (elements: HTMLElement[]) => elements.map((el) => el.textContent ?? '')

    const alerts = text(canvas.getAllByRole('alert'))
    await expect(alerts).toHaveLength(2)
    await expect(alerts.some((t) => t.includes('Careful'))).toBe(true)
    await expect(alerts.some((t) => t.includes('Could not save'))).toBe(true)

    const statuses = text(canvas.getAllByRole('status'))
    await expect(statuses).toHaveLength(3)
    for (const title of ['Heads up', 'Information', 'Saved']) {
      await expect(statuses.some((t) => t.includes(title))).toBe(true)
    }
  },
}

export const WithoutIcon: Story = {
  render: () => (
    <Alert variant="destructive" className="max-w-xl">
      <AlertDescription>Sign-in failed. Please try again.</AlertDescription>
    </Alert>
  ),
  play: async ({ canvas }) => {
    await expect(canvas.getByRole('alert')).toHaveTextContent('Sign-in failed. Please try again.')
  },
}
