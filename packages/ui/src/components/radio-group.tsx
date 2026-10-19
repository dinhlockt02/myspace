import * as React from 'react'
import { RadioGroup as RadioGroupPrimitive } from 'radix-ui'
import { Circle } from 'lucide-react'
import { cn } from '../lib/cn'
import { forcedColorsFocus } from '../lib/forced-colors'

type RadioGroupProps = React.ComponentProps<typeof RadioGroupPrimitive.Root> & {
  /** Marks the group invalid: sets `aria-invalid` on the group and the destructive boundary on its items */
  invalid?: boolean
}

function RadioGroup({ className, invalid, ...props }: RadioGroupProps) {
  return (
    <RadioGroupPrimitive.Root
      data-slot="radio-group"
      aria-invalid={invalid ? true : props['aria-invalid']}
      className={cn('group grid gap-3', className)}
      {...props}
    />
  )
}

function RadioGroupItem({ className, ...props }: React.ComponentProps<typeof RadioGroupPrimitive.Item>) {
  return (
    <RadioGroupPrimitive.Item
      data-slot="radio-group-item"
      className={cn(
        'aspect-square size-4 shrink-0 rounded-full border border-input bg-background text-primary shadow-xs outline-none',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
        forcedColorsFocus,
        'disabled:cursor-not-allowed disabled:opacity-50',
        'data-[state=checked]:border-primary',
        'group-aria-invalid:border-destructive',
        className,
      )}
      {...props}
    >
      <RadioGroupPrimitive.Indicator className="flex items-center justify-center">
        <Circle aria-hidden="true" className="size-2 fill-current" />
      </RadioGroupPrimitive.Indicator>
    </RadioGroupPrimitive.Item>
  )
}

export { RadioGroup, RadioGroupItem }
export type { RadioGroupProps }
