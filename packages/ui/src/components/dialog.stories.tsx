import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, fn, screen, userEvent, waitFor } from 'storybook/test'
import { Hourglass } from 'lucide-react'
import { Alert, AlertDescription } from './alert'
import { Button } from './button'
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from './dialog'
import { GoogleIcon } from '../icons/google-icon'

const meta = {
  title: 'Components/Dialog',
  component: Dialog,
  parameters: { layout: 'centered' },
} satisfies Meta<typeof Dialog>

export default meta
type Story = StoryObj<typeof meta>

const overlay = () => document.querySelector<HTMLElement>('[data-slot="dialog-overlay"]')!
const dialogGone = () => waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())

function ExampleDialog(props: React.ComponentProps<typeof Dialog>) {
  return (
    <Dialog {...props}>
      <DialogTrigger asChild>
        <Button type="button">Open dialog</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Edit idea</DialogTitle>
          <DialogDescription>Make changes to your idea. They are saved when you confirm.</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <DialogClose asChild>
            <Button type="button" variant="outline">
              Cancel
            </Button>
          </DialogClose>
          <Button type="button">Save</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

/** Dismissible by default: Escape, the close button and a backdrop click all close it and return focus. */
export const Dismissible: Story = {
  render: () => <ExampleDialog />,
  play: async ({ canvas }) => {
    const trigger = canvas.getByRole('button', { name: 'Open dialog' })

    await userEvent.click(trigger)
    const first = await screen.findByRole('dialog', { name: 'Edit idea' })
    // Wait for the fade-in: the dialog is transparent for the first frames
    await waitFor(() => expect(first).toBeVisible())
    await userEvent.keyboard('{Escape}')
    await dialogGone()
    await expect(trigger).toHaveFocus()

    await userEvent.click(trigger)
    await screen.findByRole('dialog')
    await userEvent.click(screen.getByRole('button', { name: 'Close' }))
    await dialogGone()
    await expect(trigger).toHaveFocus()

    await userEvent.click(trigger)
    await screen.findByRole('dialog')
    await userEvent.click(overlay())
    await dialogGone()
    await expect(trigger).toHaveFocus()
  },
}

/** Opened from the keyboard: Tab and Shift+Tab never leave the dialog, and closing returns focus to the trigger. */
export const FocusTrap: Story = {
  render: () => <ExampleDialog />,
  play: async ({ canvas }) => {
    const trigger = canvas.getByRole('button', { name: 'Open dialog' })

    await userEvent.tab()
    await expect(trigger).toHaveFocus()
    await userEvent.keyboard('{Enter}')
    const dialog = await screen.findByRole('dialog', { name: 'Edit idea' })
    await waitFor(() => expect(dialog).toContainElement(document.activeElement as HTMLElement))

    // More presses than there are focusable elements: focus must wrap inside the dialog
    for (let i = 0; i < 6; i += 1) {
      await userEvent.tab()
      await expect(dialog).toContainElement(document.activeElement as HTMLElement)
    }
    for (let i = 0; i < 6; i += 1) {
      await userEvent.tab({ shift: true })
      await expect(dialog).toContainElement(document.activeElement as HTMLElement)
    }

    await userEvent.keyboard('{Escape}')
    await dialogGone()
    await expect(trigger).toHaveFocus()
  },
}

/** The open state, so the accessibility check sees the dialog itself. */
export const Open: Story = {
  render: () => <ExampleDialog defaultOpen />,
  play: async () => {
    const dialog = await screen.findByRole('dialog', { name: 'Edit idea' })
    await expect(dialog).toHaveAccessibleDescription(/Make changes to your idea/)
    await expect(screen.getByRole('button', { name: 'Close' })).toBeInTheDocument()
  },
}

/**
 * Non-dismissible: for flows where the user has to act (the session-expired dialog). Escape and a
 * backdrop click do nothing, there is no close button, and focus stays inside the dialog.
 */
export const NonDismissible: Story = {
  args: { dismissible: false, open: true, onOpenChange: fn() },
  render: (args) => (
    <Dialog {...args}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Hourglass aria-hidden="true" className="size-5" /> Session Expired
          </DialogTitle>
          <DialogDescription>Your session timed out after one hour of inactivity.</DialogDescription>
        </DialogHeader>
        <Alert variant="info">
          <AlertDescription>Your draft has been preserved.</AlertDescription>
        </Alert>
        <Button type="button" variant="outline" className="w-full">
          <GoogleIcon /> Sign in with Google to Resume
        </Button>
      </DialogContent>
    </Dialog>
  ),
  play: async ({ args }) => {
    const dialog = await screen.findByRole('dialog', { name: /Session Expired/ })
    const action = screen.getByRole('button', { name: /Sign in with Google to Resume/ })

    // Focus starts on the only action
    await waitFor(() => expect(action).toHaveFocus())
    // No close control is rendered
    await expect(screen.queryByRole('button', { name: 'Close' })).not.toBeInTheDocument()

    await userEvent.keyboard('{Escape}')
    await userEvent.click(overlay())
    await userEvent.tab()
    await userEvent.tab({ shift: true })

    await expect(dialog).toBeVisible()
    await expect(args.onOpenChange).not.toHaveBeenCalled()
    // Focus is trapped inside the dialog
    await expect(dialog).toContainElement(document.activeElement as HTMLElement)
  },
}
