import * as React from 'react'
import { cn } from '../lib/cn'
import { forcedColorsFocus } from '../lib/forced-colors'

type InputProps = React.ComponentProps<'input'> & {
  /** Marks the field invalid: sets `aria-invalid` and the destructive boundary */
  invalid?: boolean
}

function Input({ className, type, invalid, ...props }: InputProps) {
  return (
    <input
      type={type}
      data-slot="input"
      aria-invalid={invalid ? true : props['aria-invalid']}
      className={cn(
        'flex h-9 w-full min-w-0 rounded-md border border-input bg-background px-3 py-1 text-base text-foreground shadow-xs outline-none md:text-sm',
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

export { Input }
export type { InputProps }
