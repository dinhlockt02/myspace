import * as React from 'react'
import { cn } from '../lib/cn'
import { forcedColorsFocus } from '../lib/forced-colors'

type TextareaProps = React.ComponentProps<'textarea'> & {
  /** Marks the field invalid: sets `aria-invalid` and the destructive boundary */
  invalid?: boolean
}

function Textarea({ className, invalid, ...props }: TextareaProps) {
  return (
    <textarea
      data-slot="textarea"
      aria-invalid={invalid ? true : props['aria-invalid']}
      className={cn(
        'flex min-h-16 w-full rounded-md border border-input bg-background px-3 py-2 text-base text-foreground shadow-xs outline-none md:text-sm',
        'placeholder:text-muted-foreground',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
        forcedColorsFocus,
        'disabled:cursor-not-allowed disabled:opacity-50',
        'aria-invalid:border-destructive',
        className,
      )}
      {...props}
    />
  )
}

export { Textarea }
export type { TextareaProps }
