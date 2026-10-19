import type { Meta, StoryObj } from '@storybook/react-vite'
import { Button } from './button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from './card'

const meta = {
  title: 'Components/Card',
  component: Card,
} satisfies Meta<typeof Card>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: (args) => (
    <Card {...args} className="max-w-sm">
      <CardHeader>
        <CardTitle as="h2">Personal Idea Vault</CardTitle>
        <CardDescription>Your ideas are private and only visible to you.</CardDescription>
      </CardHeader>
      <CardContent>
        <p className="text-sm">Capture a thought before it slips away.</p>
      </CardContent>
    </Card>
  ),
}

export const WithFooter: Story = {
  render: (args) => (
    <Card {...args} className="max-w-sm">
      <CardHeader>
        <CardTitle as="h2">Save changes</CardTitle>
        <CardDescription>Review your idea before saving it.</CardDescription>
      </CardHeader>
      <CardContent>
        <p className="text-sm">Nothing has been saved yet.</p>
      </CardContent>
      <CardFooter className="gap-2">
        <Button type="button">Save</Button>
        <Button type="button" variant="outline">
          Cancel
        </Button>
      </CardFooter>
    </Card>
  ),
}

export const HeadingLevels: Story = {
  render: (args) => (
    <div className="grid max-w-sm gap-4">
      <h1 className="text-2xl font-semibold">Dashboard</h1>
      <Card {...args}>
        <CardHeader>
          <CardTitle as="h2">Second-level title</CardTitle>
          <CardDescription>The heading level is chosen by the page, not the card.</CardDescription>
        </CardHeader>
      </Card>
    </div>
  ),
}
