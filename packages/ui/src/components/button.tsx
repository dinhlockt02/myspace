import * as React from 'react'
import { Slot } from 'radix-ui'
import { type VariantProps } from 'class-variance-authority'
import { cn } from '../lib/cn'
import { buttonVariants } from './button-variants'

type BaseButtonProps = React.ComponentProps<'button'> &
  Omit<VariantProps<typeof buttonVariants>, 'size'> & {
    /** Render the child element instead of a `<button>` (for links styled as buttons) */
    asChild?: boolean
  }

// An icon-only button has no visible text, so it must carry an accessible name (FR-006, User Story 4)
type IconButtonProps = { size: 'icon' } & ({ 'aria-label': string } | { 'aria-labelledby': string })
type TextButtonProps = { size?: 'sm' | 'default' | 'lg' | null }

type ButtonProps = BaseButtonProps & (IconButtonProps | TextButtonProps)

function Button({ className, variant, size, asChild = false, ...props }: ButtonProps) {
  const Comp = asChild ? Slot.Root : 'button'
  return <Comp data-slot="button" className={cn(buttonVariants({ variant, size }), className)} {...props} />
}

export { Button }
export type { ButtonProps }
