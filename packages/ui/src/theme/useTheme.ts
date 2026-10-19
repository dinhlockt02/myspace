import { createContext, useContext } from 'react'

export type Theme = 'light' | 'dark' | 'system'
export type ResolvedTheme = 'light' | 'dark'

export interface ThemeContextValue {
  /** The user's choice, including `system` */
  theme: Theme
  /** What is actually applied: `system` resolved against the OS preference */
  resolvedTheme: ResolvedTheme
  setTheme: (theme: Theme) => void
}

export const ThemeContext = createContext<ThemeContextValue | null>(null)

export function useTheme(): ThemeContextValue {
  const value = useContext(ThemeContext)
  if (!value) throw new Error('useTheme must be used within a ThemeProvider')
  return value
}
