import type { Meta, StoryObj } from '@storybook/react-vite'
import { SidebarLayout } from './sidebar-layout'

const meta = {
  title: 'Layout/SidebarLayout',
  component: SidebarLayout,
  parameters: { layout: 'fullscreen' },
} satisfies Meta<typeof SidebarLayout>

export default meta
type Story = StoryObj<typeof meta>

const Sidebar = () => (
  <nav aria-label="Sections" className="p-4">
    <ul className="grid gap-2 text-sm text-foreground">
      <li>Inbox</li>
      <li>Archive</li>
      <li>Settings</li>
    </ul>
  </nav>
)

export const Default: Story = {
  args: { sidebar: <Sidebar />, children: null },
  render: (args) => (
    <SidebarLayout {...args}>
      <main className="p-6">
        <h1 className="text-2xl font-semibold text-foreground">Content</h1>
        <p className="mt-2 text-foreground">Side by side from 1024px, stacked below.</p>
      </main>
    </SidebarLayout>
  ),
}

export const WideSidebar: Story = {
  args: { sidebar: <Sidebar />, sidebarWidth: '24rem', sidebarLabel: 'Navigation', children: null },
  render: (args) => (
    <SidebarLayout {...args}>
      <main className="p-6">
        <h1 className="text-2xl font-semibold text-foreground">Content</h1>
        <p className="mt-2 text-foreground">A 24rem sidebar from 1024px up.</p>
      </main>
    </SidebarLayout>
  ),
}
