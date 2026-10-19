import { useLayoutEffect } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, screen, userEvent, waitFor } from 'storybook/test'
import { Lightbulb } from 'lucide-react'
import { Badge } from '../components/badge'
import { Button } from '../components/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '../components/card'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '../components/dialog'
import { Tooltip, TooltipContent, TooltipTrigger } from '../components/tooltip'
import { AppHeader } from './app-header'

const meta = {
  title: 'Layout/Edge cases',
  parameters: { layout: 'padded' },
} satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const LONG_LABEL = 'A very long idea collection workspace name that cannot possibly fit on a small screen'
const UNBROKEN = 'Supercalifragilisticexpialidocious'.repeat(6)

const noHorizontalOverflow = (el: Element) => expect(el.scrollWidth).toBeLessThanOrEqual(el.clientWidth)

/** Scales rem-based sizes the way a browser text-size setting of 200% does, and undoes it on unmount */
function FontScale({ scale, children }: { scale: string; children: React.ReactNode }) {
  useLayoutEffect(() => {
    const root = document.documentElement
    const previous = root.style.fontSize
    root.style.fontSize = scale
    return () => {
      root.style.fontSize = previous
    }
  }, [scale])
  return <>{children}</>
}

/**
 * A container narrower than the 320px minimum: the brand truncates behind a tooltip that carries the
 * full text, the button label wraps, and nothing makes the container scroll sideways.
 */
export const NarrowViewport: Story = {
  render: () => (
    <div data-testid="narrow" style={{ width: 280 }}>
      <AppHeader
        className="px-3"
        brand={
          <>
            <Lightbulb aria-hidden="true" className="size-5 shrink-0 text-foreground" />
            <Tooltip>
              <TooltipTrigger asChild>
                <h1 tabIndex={0} className="truncate text-lg font-semibold text-foreground">
                  {LONG_LABEL}
                </h1>
              </TooltipTrigger>
              <TooltipContent>{LONG_LABEL}</TooltipContent>
            </Tooltip>
          </>
        }
        actions={
          <>
            <Badge variant="outline">{LONG_LABEL}</Badge>
            <Button type="button" variant="outline">
              {LONG_LABEL}
            </Button>
          </>
        }
      />
    </div>
  ),
  play: async ({ canvas }) => {
    const container = canvas.getByTestId('narrow')
    const heading = canvas.getByRole('heading', { name: LONG_LABEL })

    await noHorizontalOverflow(container)
    await noHorizontalOverflow(document.documentElement)
    const wrapped = canvas.getByRole('button', { name: LONG_LABEL })
    await noHorizontalOverflow(wrapped)
    // The wrapped label grows the button instead of spilling out of it
    await expect(wrapped.scrollHeight).toBeLessThanOrEqual(wrapped.clientHeight)
    await expect(wrapped.getBoundingClientRect().height).toBeGreaterThan(40)
    // The brand is cut off visually, so its full text must stay reachable
    await expect(heading.scrollWidth).toBeGreaterThan(heading.clientWidth)
    await userEvent.tab()
    await expect(heading).toHaveFocus()
    await expect(await screen.findByRole('tooltip')).toHaveTextContent(LONG_LABEL)
  },
}

/** Text size at 200%: the card and buttons grow with their content and the page does not scroll sideways. */
export const LargeFontScale: Story = {
  render: () => (
    <FontScale scale="200%">
      <Card data-testid="card">
        <CardHeader>
          <CardTitle>Capture a new idea</CardTitle>
          <CardDescription>Ideas are saved to your account and stay private until you share them.</CardDescription>
        </CardHeader>
        <CardContent>
          <Badge>Draft</Badge>
        </CardContent>
        <CardFooter className="flex-wrap gap-2">
          <Button type="button">Save idea and continue</Button>
          <Button type="button" variant="outline">
            Cancel
          </Button>
        </CardFooter>
      </Card>
    </FontScale>
  ),
  play: async ({ canvas }) => {
    await expect(getComputedStyle(document.documentElement).fontSize).toBe('32px')

    const save = canvas.getByRole('button', { name: 'Save idea and continue' })
    // The default button is 2.25rem tall: 36px at 100%, so a scaled button is well past that
    await expect(save.getBoundingClientRect().height).toBeGreaterThan(60)
    // The label is not clipped by the button
    await expect(save.scrollHeight).toBeLessThanOrEqual(save.clientHeight)
    await noHorizontalOverflow(save)

    await noHorizontalOverflow(canvas.getByTestId('card'))
    await noHorizontalOverflow(document.documentElement)
  },
}

/** Text size at 200% with a dialog open: it stays inside the viewport and keeps its actions reachable. */
export const LargeFontScaleDialog: Story = {
  render: () => (
    <FontScale scale="200%">
      <Dialog open>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete this idea?</DialogTitle>
            <DialogDescription>
              This removes the idea and its notes from your account. You cannot undo this.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button type="button" variant="outline">
              Keep it
            </Button>
            <Button type="button" variant="destructive">
              Delete idea
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </FontScale>
  ),
  play: async () => {
    const dialog = await screen.findByRole('dialog', { name: 'Delete this idea?' })
    await waitFor(() => expect(dialog).toBeVisible())

    const box = dialog.getBoundingClientRect()
    await expect(box.left).toBeGreaterThanOrEqual(0)
    await expect(box.right).toBeLessThanOrEqual(window.innerWidth)
    await noHorizontalOverflow(dialog)
    for (const name of ['Keep it', 'Delete idea']) {
      const button = screen.getByRole('button', { name })
      await expect(dialog).toContainElement(button)
      await expect(button.scrollHeight).toBeLessThanOrEqual(button.clientHeight)
    }
  },
}

/** A 200-character word with no break opportunities, in a Card and a Badge, inside a 320px column. */
export const LongUnbrokenText: Story = {
  render: () => (
    <div data-testid="column" style={{ width: 320 }}>
      <Card data-testid="card">
        <CardHeader>
          <CardTitle>{UNBROKEN}</CardTitle>
          <CardDescription>{UNBROKEN}</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          <p>{UNBROKEN}</p>
          <Badge data-testid="badge">{UNBROKEN}</Badge>
        </CardContent>
      </Card>
    </div>
  ),
  play: async ({ canvas }) => {
    await noHorizontalOverflow(canvas.getByTestId('column'))
    await noHorizontalOverflow(canvas.getByTestId('card'))
    await noHorizontalOverflow(canvas.getByTestId('badge'))
    await expect(canvas.getByTestId('badge').getBoundingClientRect().right).toBeLessThanOrEqual(
      canvas.getByTestId('column').getBoundingClientRect().right,
    )
  },
}
