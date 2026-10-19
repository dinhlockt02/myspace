import * as React from 'react'
import { cn } from '../lib/cn'

type SidebarLayoutProps = Omit<React.ComponentProps<'div'>, 'children'> & {
  /** Sidebar content */
  sidebar: React.ReactNode
  /** Main content */
  children: React.ReactNode
  /** Sidebar width from 1024px up, as a CSS length. Defaults to 16rem */
  sidebarWidth?: string
  /** Accessible name of the sidebar landmark. Defaults to "Sidebar" */
  sidebarLabel?: string
}

/** Sidebar and content side by side from 1024px, stacked (sidebar first) below. */
function SidebarLayout({
  sidebar,
  children,
  sidebarWidth = '16rem',
  sidebarLabel = 'Sidebar',
  className,
  style,
  ...props
}: SidebarLayoutProps) {
  return (
    <div
      data-slot="sidebar-layout"
      className={cn('flex flex-col lg:flex-row', className)}
      style={{ ...style, ['--sidebar-width' as string]: sidebarWidth }}
      {...props}
    >
      <aside
        data-slot="sidebar"
        aria-label={sidebarLabel}
        className="w-full shrink-0 border-b border-border lg:w-(--sidebar-width) lg:border-r lg:border-b-0"
      >
        {sidebar}
      </aside>
      <div data-slot="sidebar-content" className="min-w-0 flex-1">
        {children}
      </div>
    </div>
  )
}

export { SidebarLayout }
export type { SidebarLayoutProps }
