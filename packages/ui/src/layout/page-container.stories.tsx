import type { Meta, StoryObj } from '@storybook/react-vite'
import { PageContainer } from './page-container'

const meta = {
  title: 'Layout/PageContainer',
  component: PageContainer,
  parameters: { layout: 'fullscreen' },
} satisfies Meta<typeof PageContainer>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: (args) => (
    <PageContainer {...args}>
      <h1 className="py-6 text-2xl font-semibold text-foreground">Page title</h1>
      <p className="text-foreground">
        Fluid with horizontal padding on small screens, centered with a maximum width on large ones.
      </p>
    </PageContainer>
  ),
}

export const AsMain: Story = {
  render: () => (
    <PageContainer as="main">
      <h1 className="py-6 text-2xl font-semibold text-foreground">The main region</h1>
      <p className="text-foreground">Rendered as a main element.</p>
    </PageContainer>
  ),
}
