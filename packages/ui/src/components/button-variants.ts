import { cva } from 'class-variance-authority'
import { forcedColorsFocus } from '../lib/forced-colors'

export const buttonVariants = cva(
  [
    // Labels wrap instead of overflowing when the container is narrower than the label (min-h, not h)
    'inline-flex max-w-full shrink-0 items-center justify-center gap-2 rounded-md text-center text-sm font-medium wrap-anywhere',
    'transition-colors outline-none',
    'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
    forcedColorsFocus,
    'disabled:pointer-events-none disabled:opacity-50',
    "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  ],
  {
    variants: {
      variant: {
        // Filled variants lose their fill in forced colors mode, so they get a border to stay visible as controls
        default: 'bg-primary text-primary-foreground hover:bg-primary/90 active:bg-primary/80 forced-colors:border',
        secondary:
          'bg-secondary text-secondary-foreground hover:bg-secondary/80 active:bg-secondary/70 forced-colors:border',
        outline:
          'border border-input bg-background text-foreground hover:bg-accent hover:text-accent-foreground active:bg-accent/80',
        ghost: 'text-foreground hover:bg-accent hover:text-accent-foreground active:bg-accent/80',
        destructive:
          'bg-destructive text-destructive-foreground hover:bg-destructive/90 active:bg-destructive/80 forced-colors:border',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        sm: 'min-h-8 px-3 py-1',
        default: 'min-h-9 px-4 py-2',
        lg: 'min-h-10 px-6 py-2',
        icon: 'size-9',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
)
