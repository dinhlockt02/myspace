import * as React from 'react'
import { cn } from '../lib/cn'

type PageContainerProps = React.ComponentProps<'div'> & {
  /** Element or component to render; defaults to a `div` (use `main` for the page's main region) */
  as?: React.ElementType
}

/**
 * Constrains page width and padding: fluid with horizontal padding below 640px, a centered
 * maximum width from 1024px up.
 */
function PageContainer({ as: Component = 'div', className, ...props }: PageContainerProps) {
  return (
    <Component
      data-slot="page-container"
      className={cn('mx-auto w-full px-4 sm:px-6 lg:max-w-5xl lg:px-8', className)}
      {...props}
    />
  )
}

export { PageContainer }
export type { PageContainerProps }
