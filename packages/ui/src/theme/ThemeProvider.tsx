import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { ThemeContext } from './useTheme'
import type { ResolvedTheme, Theme } from './useTheme'

const DARK_QUERY = '(prefers-color-scheme: dark)'

// While a switch is in flight, transitions are suppressed so no element animates half-way between themes
const SWITCHING_CSS =
  '[data-theme-switching] *,[data-theme-switching] *::before,[data-theme-switching] *::after{transition:none!important}'

const isTheme = (value: unknown): value is Theme => value === 'light' || value === 'dark' || value === 'system'

function readStoredTheme(storageKey: string): Theme | null {
  try {
    const value = localStorage.getItem(storageKey)
    return isTheme(value) ? value : null
  } catch {
    return null
  }
}

function writeStoredTheme(storageKey: string, theme: Theme) {
  try {
    localStorage.setItem(storageKey, theme)
  } catch {
    // Storage is unavailable (private mode, blocked): the choice lives in memory only
  }
}

const prefersDark = () => typeof window.matchMedia === 'function' && window.matchMedia(DARK_QUERY).matches

interface ThemeProviderProps {
  children: ReactNode
  /** Used when nothing valid is stored. Defaults to `system` */
  defaultTheme?: Theme
  /** localStorage key. Defaults to `ui-theme`, which `themeInitScript` reads */
  storageKey?: string
}

export function ThemeProvider({ children, defaultTheme = 'system', storageKey = 'ui-theme' }: ThemeProviderProps) {
  const [theme, setThemeState] = useState<Theme>(() => readStoredTheme(storageKey) ?? defaultTheme)
  const [systemDark, setSystemDark] = useState<boolean>(prefersDark)
  const frame = useRef<number | null>(null)
  const switchingStyle = useRef<HTMLStyleElement | null>(null)

  const resolvedTheme: ResolvedTheme = theme === 'system' ? (systemDark ? 'dark' : 'light') : theme

  // Follow the OS only while the value is `system`; the listener is harmless otherwise because
  // resolvedTheme ignores systemDark for an explicit theme
  useEffect(() => {
    if (typeof window.matchMedia !== 'function') return
    const query = window.matchMedia(DARK_QUERY)
    const onChange = (event: { matches: boolean }) => setSystemDark(event.matches)
    query.addEventListener('change', onChange)
    return () => query.removeEventListener('change', onChange)
  }, [])

  const endSwitching = useCallback(() => {
    frame.current = null
    document.documentElement.removeAttribute('data-theme-switching')
    switchingStyle.current?.remove()
    switchingStyle.current = null
  }, [])

  useLayoutEffect(() => {
    const root = document.documentElement
    const wantsDark = resolvedTheme === 'dark'
    if (root.classList.contains('dark') === wantsDark && root.style.colorScheme === resolvedTheme) return

    root.setAttribute('data-theme-switching', '')
    if (!switchingStyle.current) {
      const style = document.createElement('style')
      style.setAttribute('data-theme-switching-style', '')
      style.textContent = SWITCHING_CSS
      document.head.appendChild(style)
      switchingStyle.current = style
    }
    root.classList.toggle('dark', wantsDark)
    root.style.colorScheme = resolvedTheme

    // Hold the marker for one frame after the styles have been recalculated; restart it on rapid changes
    if (frame.current !== null) cancelAnimationFrame(frame.current)
    frame.current = requestAnimationFrame(endSwitching)
  }, [resolvedTheme, endSwitching])

  useEffect(
    () => () => {
      if (frame.current !== null) cancelAnimationFrame(frame.current)
      endSwitching()
    },
    [endSwitching],
  )

  const setTheme = useCallback(
    (next: Theme) => {
      setThemeState(next)
      writeStoredTheme(storageKey, next)
    },
    [storageKey],
  )

  const value = useMemo(() => ({ theme, resolvedTheme, setTheme }), [theme, resolvedTheme, setTheme])

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}
