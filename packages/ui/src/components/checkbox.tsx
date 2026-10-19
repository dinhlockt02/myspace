import * as React from 'react'
import { Checkbox as CheckboxPrimitive } from 'radix-ui'
import { Check, Minus } from 'lucide-react'
import { cn } from '../lib/cn'
import { forcedColorsFocus } from '../lib/forced-colors'

type CheckboxProps = React.ComponentProps<typeof CheckboxPrimitive.Root> & {
  /** Marks the control invalid: sets `aria-invalid` and the destructive boundary */
  invalid?: boolean
}

function Checkbox({ className, invalid, ...props }: CheckboxProps) {
  return (
    <CheckboxPrimitive.Root
      data-slot="checkbox"
      aria-invalid={invalid ? true : props['aria-invalid']}
      className={cn(
        'group peer size-4 shrink-0 rounded-[4px] border border-input bg-background text-primary-foreground shadow-xs outline-none',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
        forcedColorsFocus,
        'disabled:cursor-not-allowed disabled:opacity-50',
        'data-[state=checked]:border-primary data-[state=checked]:bg-primary',
        'data-[state=indeterminate]:border-primary data-[state=indeterminate]:bg-primary',
        'aria-invalid:border-destructive',
        className,
      )}
      {...props}
    >
      <CheckboxPrimitive.Indicator data-slot="checkbox-indicator" className="flex items-center justify-center text-current">
        <Check aria-hidden="true" className="size-3.5 group-data-[state=indeterminate]:hidden" />
        <Minus aria-hidden="true" className="hidden size-3.5 group-data-[state=indeterminate]:block" />
      </CheckboxPrimitive.Indicator>
    </CheckboxPrimitive.Root>
  )
}

export { Checkbox }
export type { CheckboxProps }
