import type { Meta, StoryObj } from '@storybook/react-vite'
import { Lightbulb, User } from 'lucide-react'
import { Badge } from '../components/badge'
import { Button } from '../components/button'
import { AppHeader } from './app-header'
import { PageContainer } from './page-container'

const meta = {
  title: 'Layout/AppHeader',
  component: AppHeader,
  parameters: { layout: 'fullscreen' },
} satisfies Meta<typeof AppHeader>

export default meta
type Story = StoryObj<typeof meta>

const Brand = () => (
  <>
    <Lightbulb aria-hidden="true" className="size-5 text-foreground" />
    <h1 className="text-lg font-semibold text-foreground">Idea Collector</h1>
  </>
)

export const BrandOnly: Story = {
  args: { brand: <Brand /> },
  render: (args) => (
    <PageContainer>
      <AppHeader {...args} />
    </PageContainer>
  ),
}

export const WithActions: Story = {
  args: { brand: <Brand /> },
  render: (args) => (
    <PageContainer>
      <AppHeader
        {...args}
        actions={
          <>
            <Badge variant="outline">
              <User aria-hidden="true" /> ada@example.com
            </Badge>
            <Button type="button" variant="outline" size="sm">
              Sign Out
            </Button>
          </>
        }
      />
    </PageContainer>
  ),
}
