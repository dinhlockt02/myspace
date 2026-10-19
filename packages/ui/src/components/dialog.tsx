import * as React from 'react'
import { Dialog as DialogPrimitive } from 'radix-ui'
import { X } from 'lucide-react'
import { cn } from '../lib/cn'
import { forcedColorsFocus } from '../lib/forced-colors'

// Whether the dialog may be dismissed by Escape, a backdrop click or a close button (FR-016)
const DismissibleContext = React.createContext(true)

type DialogProps = React.ComponentProps<typeof DialogPrimitive.Root> & {
  /**
   * Dismissible by default (Escape, close button, backdrop click). Set to `false` for flows where
   * the user has to act, such as an expired session: none of those dismiss the dialog and no close
   * button is rendered. A non-dismissible dialog should be controlled and offer its own action.
   */
  dismissible?: boolean
}

function Dialog({ dismissible = true, ...props }: DialogProps) {
  return (
    <DismissibleContext.Provider value={dismissible}>
      <DialogPrimitive.Root data-slot="dialog" {...props} />
    </DismissibleContext.Provider>
  )
}

function DialogTrigger(props: React.ComponentProps<typeof DialogPrimitive.Trigger>) {
  return <DialogPrimitive.Trigger data-slot="dialog-trigger" {...props} />
}

function DialogClose(props: React.ComponentProps<typeof DialogPrimitive.Close>) {
  return <DialogPrimitive.Close data-slot="dialog-close" {...props} />
}

function DialogOverlay({ className, ...props }: React.ComponentProps<typeof DialogPrimitive.Overlay>) {
  return (
    <DialogPrimitive.Overlay
      data-slot="dialog-overlay"
      className={cn(
        'fixed inset-0 z-50 bg-background/80 backdrop-blur-sm forced-colors:bg-transparent',
        'data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=closed]:animate-out data-[state=closed]:fade-out-0',
        className,
      )}
      {...props}
    />
  )
}

function DialogContent({ className, children, ...props }: React.ComponentProps<typeof DialogPrimitive.Content>) {
  const dismissible = React.useContext(DismissibleContext)
  const keepOpen = dismissible ? undefined : (event: Event) => event.preventDefault()

  return (
    <DialogPrimitive.Portal>
      <DialogOverlay />
      <DialogPrimitive.Content
        data-slot="dialog-content"
        onEscapeKeyDown={keepOpen}
        onPointerDownOutside={keepOpen}
        onInteractOutside={keepOpen}
        className={cn(
          'fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 sm:max-w-lg',
          'rounded-lg border border-border bg-background p-6 text-foreground shadow-lg outline-none',
          'data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95',
          'data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95',
          className,
        )}
        {...props}
      >
        {children}
        {dismissible && (
          <DialogPrimitive.Close
            data-slot="dialog-close-button"
            className={cn(
              'absolute top-4 right-4 rounded-sm text-foreground opacity-70 outline-none transition-opacity hover:opacity-100 [&_svg]:size-4',
              'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
              forcedColorsFocus,
            )}
          >
            <X aria-hidden="true" />
            <span className="sr-only">Close</span>
          </DialogPrimitive.Close>
        )}
      </DialogPrimitive.Content>
    </DialogPrimitive.Portal>
  )
}

function DialogHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div data-slot="dialog-header" className={cn('flex flex-col gap-2 text-center sm:text-left', className)} {...props} />
  )
}

function DialogFooter({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="dialog-footer"
      className={cn('flex flex-col-reverse gap-2 sm:flex-row sm:justify-end', className)}
      {...props}
    />
  )
}

function DialogTitle({ className, ...props }: React.ComponentProps<typeof DialogPrimitive.Title>) {
  return (
    <DialogPrimitive.Title data-slot="dialog-title" className={cn('text-lg leading-none font-semibold', className)} {...props} />
  )
}

function DialogDescription({ className, ...props }: React.ComponentProps<typeof DialogPrimitive.Description>) {
  return (
    <DialogPrimitive.Description
      data-slot="dialog-description"
      className={cn('text-sm text-muted-foreground', className)}
      {...props}
    />
  )
}

export {
  Dialog,
  DialogTrigger,
  DialogClose,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
}
