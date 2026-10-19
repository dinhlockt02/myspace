import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '../lib/cn'

const alertVariants = cva(
  [
    'relative grid w-full grid-cols-[0_1fr] items-start gap-y-0.5 rounded-lg border px-4 py-3 text-sm',
    'has-[>svg]:grid-cols-[calc(var(--spacing)*4)_1fr] has-[>svg]:gap-x-3',
    '[&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current',
  ],
  {
    variants: {
      variant: {
        default: 'border-border bg-card text-card-foreground',
        destructive: 'border-destructive bg-card text-destructive',
        success: 'border-success bg-card text-success',
        warning: 'border-warning bg-card text-warning',
        info: 'border-info bg-card text-info',
      },
    },
    defaultVariants: { variant: 'default' },
  },
)

type AlertVariant = NonNullable<VariantProps<typeof alertVariants>['variant']>

// Urgent messages interrupt (role="alert"); the rest are polite status updates
const ROLE: Record<AlertVariant, 'alert' | 'status'> = {
  default: 'status',
  destructive: 'alert',
  success: 'status',
  warning: 'alert',
  info: 'status',
}

type AlertProps = React.ComponentProps<'div'> & VariantProps<typeof alertVariants>

function Alert({ className, variant = 'default', role, ...props }: AlertProps) {
  return (
    <div
      data-slot="alert"
      role={role ?? ROLE[variant ?? 'default']}
      className={cn(alertVariants({ variant }), className)}
      {...props}
    />
  )
}

function AlertTitle({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div data-slot="alert-title" className={cn('col-start-2 min-h-4 font-medium tracking-tight', className)} {...props} />
  )
}

function AlertDescription({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div data-slot="alert-description" className={cn('col-start-2 grid justify-items-start gap-1 text-sm [&_p]:leading-relaxed', className)} {...props} />
  )
}

export { Alert, AlertTitle, AlertDescription }
