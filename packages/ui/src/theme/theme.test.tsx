import { act, cleanup, render, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ThemeProvider } from './ThemeProvider'
import { useTheme } from './useTheme'
import { themeInitScript } from './theme-init'

type Listener = (event: { matches: boolean }) => void

// A controllable prefers-color-scheme: jsdom has no matchMedia
let systemDark = false
let listeners = new Set<Listener>()

const installMatchMedia = () => {
  listeners = new Set()
  window.matchMedia = ((query: string) => ({
    get matches() {
      return query.includes('dark') ? systemDark : false
    },
    media: query,
    addEventListener: (_: string, l: Listener) => listeners.add(l),
    removeEventListener: (_: string, l: Listener) => listeners.delete(l),
    addListener: (l: Listener) => listeners.add(l),
    removeListener: (l: Listener) => listeners.delete(l),
    onchange: null,
    dispatchEvent: () => true,
  })) as unknown as typeof window.matchMedia
}

const setSystemDark = (dark: boolean) => {
  systemDark = dark
  act(() => listeners.forEach((l) => l({ matches: dark })))
}

const root = document.documentElement

let api: ReturnType<typeof useTheme>
const Probe = () => {
  api = useTheme()
  return null
}

const mount = (props: { defaultTheme?: 'light' | 'dark' | 'system'; storageKey?: string } = {}) =>
  render(
    <ThemeProvider {...props}>
      <Probe />
    </ThemeProvider>,
  )

const nextFrame = () => new Promise<void>((resolve) => requestAnimationFrame(() => resolve()))

beforeEach(() => {
  systemDark = false
  installMatchMedia()
  localStorage.clear()
  root.classList.remove('dark')
  root.style.removeProperty('color-scheme')
  root.removeAttribute('data-theme-switching')
})

afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})

describe('ThemeProvider and useTheme', () => {
  it('defaults to system and resolves it to light when the OS prefers light', () => {
    mount()
    expect(api.theme).toBe('system')
    expect(api.resolvedTheme).toBe('light')
    expect(root.classList.contains('dark')).toBe(false)
  })

  it('resolves system to dark when prefers-color-scheme: dark matches', () => {
    systemDark = true
    mount()
    expect(api.theme).toBe('system')
    expect(api.resolvedTheme).toBe('dark')
    expect(root.classList.contains('dark')).toBe(true)
  })

  it('setTheme("dark") adds the dark class, sets color-scheme and writes ui-theme', () => {
    mount()
    act(() => api.setTheme('dark'))
    expect(api.theme).toBe('dark')
    expect(api.resolvedTheme).toBe('dark')
    expect(root.classList.contains('dark')).toBe(true)
    expect(root.style.colorScheme).toBe('dark')
    expect(localStorage.getItem('ui-theme')).toBe('dark')
  })

  it('setTheme("light") removes the dark class and sets color-scheme light', () => {
    systemDark = true
    mount()
    act(() => api.setTheme('light'))
    expect(root.classList.contains('dark')).toBe(false)
    expect(root.style.colorScheme).toBe('light')
    expect(localStorage.getItem('ui-theme')).toBe('light')
  })

  it('honours a custom storageKey and defaultTheme', () => {
    mount({ defaultTheme: 'dark', storageKey: 'my-theme' })
    expect(api.theme).toBe('dark')
    act(() => api.setTheme('light'))
    expect(localStorage.getItem('my-theme')).toBe('light')
    expect(localStorage.getItem('ui-theme')).toBeNull()
  })

  it('restores a stored theme on mount', () => {
    localStorage.setItem('ui-theme', 'dark')
    mount()
    expect(api.theme).toBe('dark')
    expect(root.classList.contains('dark')).toBe(true)
  })

  it('falls back to system when the stored value is not light, dark or system', () => {
    localStorage.setItem('ui-theme', 'solarized')
    mount()
    expect(api.theme).toBe('system')
    expect(api.resolvedTheme).toBe('light')
  })

  it('keeps working in memory when localStorage throws, and falls back to system on reload', () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('storage unavailable')
    })
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('storage unavailable')
    })

    const first = mount()
    expect(api.theme).toBe('system')
    act(() => api.setTheme('dark'))
    expect(api.theme).toBe('dark')
    expect(root.classList.contains('dark')).toBe(true)

    first.unmount()
    root.classList.remove('dark')
    mount()
    expect(api.theme).toBe('system')
    expect(api.resolvedTheme).toBe('light')
  })

  it('follows an OS preference change while the value is system, without writing storage', () => {
    mount()
    expect(api.resolvedTheme).toBe('light')

    setSystemDark(true)
    expect(api.resolvedTheme).toBe('dark')
    expect(root.classList.contains('dark')).toBe(true)

    setSystemDark(false)
    expect(api.resolvedTheme).toBe('light')
    expect(localStorage.getItem('ui-theme')).toBeNull()
  })

  it('ignores OS preference changes once an explicit theme is chosen', () => {
    mount()
    act(() => api.setTheme('light'))
    setSystemDark(true)
    expect(api.resolvedTheme).toBe('light')
    expect(root.classList.contains('dark')).toBe(false)
  })

  it('ends in the last requested state after 50 rapid changes, with no leftover data-theme-switching', async () => {
    mount()
    act(() => {
      for (let i = 0; i < 50; i += 1) api.setTheme(i % 2 === 0 ? 'dark' : 'light')
    })
    // i = 49 is the last call: light
    expect(api.theme).toBe('light')
    expect(root.classList.contains('dark')).toBe(false)

    await waitFor(() => expect(root.hasAttribute('data-theme-switching')).toBe(false))
    expect(document.querySelector('style[data-theme-switching-style]')).toBeNull()
  })

  it('marks the document as switching for one frame around a change', async () => {
    mount()
    act(() => api.setTheme('dark'))
    expect(root.hasAttribute('data-theme-switching')).toBe(true)
    await nextFrame()
    await nextFrame()
    expect(root.hasAttribute('data-theme-switching')).toBe(false)
  })

  it('throws a clear error when useTheme is used outside a ThemeProvider', () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {})
    expect(() => render(<Probe />)).toThrow(/ThemeProvider/)
    spy.mockRestore()
  })
})

describe('theme-init script', () => {
  const run = () => new Function(themeInitScript)()

  it('sets the dark class and color-scheme from a stored dark value', () => {
    localStorage.setItem('ui-theme', 'dark')
    run()
    expect(root.classList.contains('dark')).toBe(true)
    expect(root.style.colorScheme).toBe('dark')
  })

  it('omits the dark class for a stored light value even when the OS prefers dark', () => {
    systemDark = true
    localStorage.setItem('ui-theme', 'light')
    run()
    expect(root.classList.contains('dark')).toBe(false)
    expect(root.style.colorScheme).toBe('light')
  })

  it('follows the OS preference when nothing is stored', () => {
    systemDark = true
    run()
    expect(root.classList.contains('dark')).toBe(true)
  })

  it('follows the OS preference for a stored system value and ignores an invalid one', () => {
    systemDark = true
    localStorage.setItem('ui-theme', 'system')
    run()
    expect(root.classList.contains('dark')).toBe(true)

    root.classList.remove('dark')
    systemDark = false
    localStorage.setItem('ui-theme', 'nonsense')
    run()
    expect(root.classList.contains('dark')).toBe(false)
  })

  it('does not throw when localStorage is unavailable', () => {
    systemDark = true
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('storage unavailable')
    })
    expect(run).not.toThrow()
    expect(root.classList.contains('dark')).toBe(true)
  })

  it('agrees with ThemeProvider on the initial state for the same inputs', () => {
    systemDark = true
    localStorage.setItem('ui-theme', 'system')
    run()
    const scripted = root.classList.contains('dark')

    cleanup()
    root.classList.remove('dark')
    mount()
    expect(root.classList.contains('dark')).toBe(scripted)
  })
})
