import type { Meta, StoryObj } from '@storybook/react-vite'
import { Button } from './button'
import { Checkbox } from './checkbox'
import { Input } from './input'
import { RadioGroup, RadioGroupItem } from './radio-group'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './select'
import { Spinner } from './spinner'
import { Textarea } from './textarea'

const meta = {
  title: 'Accessibility/Forced colors',
  parameters: {
    layout: 'padded',
    docs: {
      description: {
        component:
          'In forced colors mode (Windows High Contrast) the operating system replaces colors, backgrounds and ' +
          'box-shadows. Controls keep a visible boundary through their borders, filled buttons gain a border, ' +
          'and the focus indicator switches from a ring (a box-shadow) to an outline. ' +
          'To check by hand, turn on Windows contrast themes, or in Chrome DevTools open Rendering and set ' +
          '"Emulate CSS media feature forced-colors" to active, then Tab through this story.',
      },
    },
  },
} satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

/** Every control that has a boundary or a focus indicator. Verify with forced colors on, then Tab through. */
export const Controls: Story = {
  render: () => (
    <div className="grid max-w-md gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <Button type="button">Default</Button>
        <Button type="button" variant="secondary">
          Secondary
        </Button>
        <Button type="button" variant="outline">
          Outline
        </Button>
        <Button type="button" variant="destructive">
          Destructive
        </Button>
        <Button type="button" disabled>
          Disabled
        </Button>
      </div>
      <Input aria-label="Name" placeholder="Input" />
      <Textarea aria-label="Notes" placeholder="Textarea" rows={2} />
      <Select defaultValue="light">
        <SelectTrigger aria-label="Theme">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="light">Light</SelectItem>
          <SelectItem value="dark">Dark</SelectItem>
        </SelectContent>
      </Select>
      <div className="flex items-center gap-2">
        <Checkbox id="fc-check" defaultChecked />
        <label htmlFor="fc-check" className="text-sm text-foreground">
          Checkbox
        </label>
      </div>
      <RadioGroup defaultValue="a" aria-label="Choice">
        <div className="flex items-center gap-2">
          <RadioGroupItem id="fc-a" value="a" />
          <label htmlFor="fc-a" className="text-sm text-foreground">
            Radio A
          </label>
        </div>
        <div className="flex items-center gap-2">
          <RadioGroupItem id="fc-b" value="b" />
          <label htmlFor="fc-b" className="text-sm text-foreground">
            Radio B
          </label>
        </div>
      </RadioGroup>
      <Spinner label="Loading" />
    </div>
  ),
}
