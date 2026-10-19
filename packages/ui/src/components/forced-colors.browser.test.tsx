import { afterEach, beforeAll, describe, expect, it } from 'vitest'
import { cdp } from 'vitest/browser'
import { cleanup, render, screen } from '@testing-library/react'
import '../styles/storybook.css'
import { Button } from './button'
import { Checkbox } from './checkbox'
import { Dialog, DialogContent, DialogDescription, DialogTitle } from './dialog'
import { Input } from './input'
import { RadioGroup, RadioGroupItem } from './radio-group'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './select'
import { Textarea } from './textarea'

// Forced colors mode (Windows High Contrast) drops box-shadows, so a `ring-*` focus indicator disappears.
// Chromium can emulate the mode, which lets us check what the OS would otherwise show.

const setForcedColors = (value: 'active' | 'none') =>
  cdp().send('Emulation.setEmulatedMedia', { features: [{ name: 'forced-colors', value }] })

const outline = (el: HTMLElement) => {
  const style = getComputedStyle(el)
  return { style: style.outlineStyle, width: parseFloat(style.outlineWidth) }
}

const focusables: Record<string, () => HTMLElement> = {
  Button: () => screen.getByRole('button', { name: 'Save' }),
  Input: () => screen.getByRole('textbox', { name: 'Name' }),
  Textarea: () => screen.getByRole('textbox', { name: 'Notes' }),
  'Select trigger': () => screen.getByRole('combobox', { name: 'Theme' }),
  Checkbox: () => screen.getByRole('checkbox', { name: 'Remember me' }),
  'Radio item': () => screen.getByRole('radio', { name: 'A' }),
}

const renderControls = () =>
  render(
    <div>
      <Button type="button">Save</Button>
      <Input aria-label="Name" />
      <Textarea aria-label="Notes" />
      <Select defaultValue="light">
        <SelectTrigger aria-label="Theme">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="light">Light</SelectItem>
        </SelectContent>
      </Select>
      <Checkbox aria-label="Remember me" />
      <RadioGroup aria-label="Choice">
        <RadioGroupItem aria-label="A" value="a" />
      </RadioGroup>
    </div>,
  )

beforeAll(() => setForcedColors('none'))
afterEach(async () => {
  cleanup()
  await setForcedColors('none')
})

describe('forced colors mode', () => {
  describe.each(Object.entries(focusables))('%s', (_name, find) => {
    it('shows an outline on keyboard focus when forced colors are active', async () => {
      await setForcedColors('active')
      renderControls()
      const el = find()
      el.focus()
      expect(el.matches(':focus-visible')).toBe(true)
      expect(outline(el)).toEqual({ style: 'solid', width: 2 })
    })

    it('keeps the ring-only focus indicator, with no outline, otherwise', () => {
      renderControls()
      const el = find()
      el.focus()
      expect(outline(el).style).toBe('none')
    })
  })

  it('gives filled buttons a border so they stay visible as controls', async () => {
    await setForcedColors('active')
    render(
      <>
        <Button type="button">Default</Button>
        <Button type="button" variant="secondary">
          Secondary
        </Button>
        <Button type="button" variant="destructive">
          Destructive
        </Button>
      </>,
    )
    for (const name of ['Default', 'Secondary', 'Destructive']) {
      expect(parseFloat(getComputedStyle(screen.getByRole('button', { name })).borderTopWidth)).toBeGreaterThan(0)
    }
  })

  it('shows an outline on the dialog close button and keeps the dialog bordered', async () => {
    await setForcedColors('active')
    render(
      <Dialog open>
        <DialogContent>
          <DialogTitle>Title</DialogTitle>
          <DialogDescription>Description</DialogDescription>
        </DialogContent>
      </Dialog>,
    )
    const close = await screen.findByRole('button', { name: 'Close' })
    close.focus()
    expect(outline(close)).toEqual({ style: 'solid', width: 2 })
    expect(parseFloat(getComputedStyle(screen.getByRole('dialog')).borderTopWidth)).toBeGreaterThan(0)
  })
})
