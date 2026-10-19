import * as React from 'react'
import { cn } from '../lib/cn'

type AppHeaderProps = Omit<React.ComponentProps<'header'>, 'children'> & {
  /** Left side: the logo and application name */
  brand: React.ReactNode
  /** Right side: user info, buttons. Wraps under the brand below 640px */
  actions?: React.ReactNode
}

/** Application top bar with a brand slot and an actions slot. */
function AppHeader({ brand, actions, className, ...props }: AppHeaderProps) {
  return (
    <header
      data-slot="app-header"
      className={cn(
        'flex flex-col items-start gap-3 border-b border-border py-4 sm:flex-row sm:items-center sm:justify-between',
        className,
      )}
      {...props}
    >
      <div data-slot="app-header-brand" className="flex min-w-0 items-center gap-2">
        {brand}
      </div>
      {actions && (
        <div data-slot="app-header-actions" className="flex min-w-0 flex-wrap items-center gap-3">
          {actions}
        </div>
      )}
    </header>
  )
}

export { AppHeader }
export type { AppHeaderProps }
