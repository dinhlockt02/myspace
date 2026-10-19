import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect } from 'storybook/test'
import { Spinner } from './spinner'

const meta = {
  title: 'Components/Spinner',
  component: Spinner,
} satisfies Meta<typeof Spinner>

export default meta
type Story = StoryObj<typeof meta>

export const Sizes: Story = {
  render: () => (
    <div className="flex items-center gap-6">
      <Spinner size="sm" label="Loading small" />
      <Spinner label="Loading default" />
      <Spinner size="lg" label="Loading large" />
    </div>
  ),
  // Each spinner is a status region whose text is its label; the rotating icon is hidden from screen readers
  play: async ({ canvas }) => {
    const statuses = canvas.getAllByRole('status')
    await expect(statuses).toHaveLength(3)
    const labels = ['Loading small', 'Loading default', 'Loading large']
    statuses.forEach((status, i) => {
      expect(status).toHaveTextContent(labels[i])
      expect(status.querySelector('svg')).toHaveAttribute('aria-hidden', 'true')
    })
  },
}

export const WithText: Story = {
  render: () => (
    <div className="flex items-center gap-3 text-sm text-muted-foreground">
      <Spinner label="Loading your ideas" />
      <span aria-hidden="true">Loading your ideas...</span>
    </div>
  ),
  play: async ({ canvas }) => {
    // Announced once, through the spinner's label, not twice
    await expect(canvas.getByRole('status')).toHaveTextContent('Loading your ideas')
    await expect(canvas.queryByText('Loading your ideas...')).toBeInTheDocument()
    await expect(canvas.getByText('Loading your ideas...')).toHaveAttribute('aria-hidden', 'true')
  },
}
