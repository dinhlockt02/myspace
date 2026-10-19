import * as React from 'react'
import { LoaderCircle } from 'lucide-react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '../lib/cn'

const spinnerVariants = cva('animate-spin text-muted-foreground forced-colors:text-[color:CanvasText]', {
  variants: {
    size: { sm: 'size-4', default: 'size-6', lg: 'size-10' },
  },
  defaultVariants: { size: 'default' },
})

type SpinnerProps = Omit<React.ComponentProps<'span'>, 'children'> &
  VariantProps<typeof spinnerVariants> & {
    /** Accessible name announced to screen readers; not shown visually */
    label?: string
  }

function Spinner({ className, size, label = 'Loading', ...props }: SpinnerProps) {
  return (
    <span data-slot="spinner" role="status" className={cn('inline-flex items-center', className)} {...props}>
      <LoaderCircle aria-hidden="true" className={spinnerVariants({ size })} />
      <span className="sr-only">{label}</span>
    </span>
  )
}

export { Spinner }
export type { SpinnerProps }
