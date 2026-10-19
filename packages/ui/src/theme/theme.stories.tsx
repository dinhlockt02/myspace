import { useState } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, userEvent, waitFor } from 'storybook/test'
import { Button } from '../components/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/card'
import { ThemeProvider } from './ThemeProvider'
import { useTheme } from './useTheme'
import type { Theme } from './useTheme'

const STORY_STORAGE_KEY = 'ui-theme-story'
const choices: { label: string; value: Theme }[] = [
  { label: 'Light', value: 'light' },
  { label: 'Dark', value: 'dark' },
  { label: 'System', value: 'system' },
]

function ThemeControl() {
  const { theme, resolvedTheme, setTheme } = useTheme()
  return (
    <Card className="w-96">
      <CardHeader>
        <CardTitle>Theme</CardTitle>
        <CardDescription>
          Selected: {theme}, applied: {resolvedTheme}
        </CardDescription>
      </CardHeader>
      <CardContent className="flex gap-2">
        {choices.map(({ label, value }) => (
          <Button
            key={value}
            type="button"
            variant={theme === value ? 'default' : 'outline'}
            aria-pressed={theme === value}
            onClick={() => setTheme(value)}
          >
            {label}
          </Button>
        ))}
      </CardContent>
    </Card>
  )
}

// The story owns the theme while it is mounted, so it starts from whatever the Storybook toolbar applied
// and ignores anything an earlier visit stored.
function ThemeDemo() {
  const [initial] = useState<Theme>(() => {
    try {
      localStorage.removeItem(STORY_STORAGE_KEY)
    } catch {
      // Storage unavailable: nothing to clear
    }
    return document.documentElement.classList.contains('dark') ? 'dark' : 'light'
  })
  return (
    <ThemeProvider defaultTheme={initial} storageKey={STORY_STORAGE_KEY}>
      <ThemeControl />
    </ThemeProvider>
  )
}

const meta = {
  title: 'Theme/ThemeProvider',
  component: ThemeDemo,
  parameters: { layout: 'centered' },
} satisfies Meta<typeof ThemeDemo>

export default meta
type Story = StoryObj<typeof meta>

export const Switching: Story = {
  play: async ({ canvas, step }) => {
    const root = document.documentElement
    const isDark = () => root.classList.contains('dark')
    const pick = (name: string) => userEvent.click(canvas.getByRole('button', { name }))
    const startedDark = isDark()
    // Dark comes first: the Storybook toolbar may have applied its own class before the provider mounted,
    // so the first step must be a real state change for the provider to take over from there.

    await step('dark', async () => {
      await pick('Dark')
      await waitFor(() => expect(isDark()).toBe(true))
      await expect(canvas.getByRole('button', { name: 'Dark' })).toHaveAttribute('aria-pressed', 'true')
    })

    await step('light', async () => {
      await pick('Light')
      await waitFor(() => expect(isDark()).toBe(false))
      await expect(canvas.getByRole('button', { name: 'Light' })).toHaveAttribute('aria-pressed', 'true')
    })

    await step('system follows the OS preference', async () => {
      await pick('System')
      const osDark = window.matchMedia('(prefers-color-scheme: dark)').matches
      await waitFor(() => expect(isDark()).toBe(osDark))
    })

    await step('20 rapid toggles end in the last choice', async () => {
      for (let i = 0; i < 20; i += 1) await pick(i % 2 === 0 ? 'Light' : 'Dark')
      // The last iteration (i = 19) picked Dark
      await waitFor(() => expect(isDark()).toBe(true))
      await waitFor(() => expect(root).not.toHaveAttribute('data-theme-switching'))
    })

    // Leave the toolbar's theme in place for the accessibility check that runs after this
    await pick(startedDark ? 'Dark' : 'Light')
    await waitFor(() => expect(isDark()).toBe(startedDark))
  },
}
