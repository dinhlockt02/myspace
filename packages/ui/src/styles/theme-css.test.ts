import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import { colorTokens, radius } from '../tokens/tokens'

const raw = readFileSync(resolve(__dirname, 'theme.css'), 'utf8')
const noComments = raw.replace(/\/\*[\s\S]*?\*\//g, '')
// At-rule statements without a block (@import, @custom-variant) are not selectors
const css = noComments.replace(/@[a-z-]+[^{};]*;/g, '')

// Flat blocks only: theme.css has no nesting, which keeps this check simple and strict
const blocks = [...css.matchAll(/([^{}]+)\{([^{}]*)\}/g)].map((m) => ({
  selector: m[1].trim(),
  body: m[2],
}))

const declared = (selector: string): Map<string, string> =>
  new Map(
    blocks
      .filter((b) => b.selector === selector)
      .flatMap((b) => [...b.body.matchAll(/(--[a-z0-9-]+)\s*:\s*([^;]+);/g)].map((m) => [m[1], m[2].trim()] as const)),
  )

describe('theme.css (FR-009: no global style leakage)', () => {
  it('contains only :root, .dark and @theme blocks, so no element selector can leak', () => {
    const unexpected = blocks
      .map((b) => b.selector)
      .filter((s) => s !== ':root' && s !== '.dark' && !s.startsWith('@theme'))
    expect(unexpected).toEqual([])
  })

  it('does not import the Tailwind base reset', () => {
    expect(noComments).not.toMatch(/tailwindcss\/preflight/)
  })

  it('maps tokens to Tailwind with @theme inline and declares the dark variant', () => {
    expect(noComments).toMatch(/@theme\s+inline\s*\{/)
    expect(noComments).toMatch(/@custom-variant\s+dark\s*\(/)
  })

  it('defines every color token in both :root and .dark', () => {
    const light = declared(':root')
    const dark = declared('.dark')
    const missing = colorTokens.flatMap((t) => [
      ...(light.has(`--${t.name}`) ? [] : [`--${t.name} (:root)`]),
      ...(dark.has(`--${t.name}`) ? [] : [`--${t.name} (.dark)`]),
    ])
    expect(missing).toEqual([])
  })

  it('has the same values as the token manifest, so the contrast test covers what ships', () => {
    const light = declared(':root')
    const dark = declared('.dark')
    const different = colorTokens.flatMap((t) => [
      ...(light.get(`--${t.name}`) === t.light ? [] : [`--${t.name} light: css ${light.get(`--${t.name}`)} vs manifest ${t.light}`]),
      ...(dark.get(`--${t.name}`) === t.dark ? [] : [`--${t.name} dark: css ${dark.get(`--${t.name}`)} vs manifest ${t.dark}`]),
    ])
    expect(different).toEqual([])
  })

  it('maps every token to a Tailwind color in @theme inline', () => {
    const theme = new Map(
      blocks
        .filter((b) => b.selector.startsWith('@theme'))
        .flatMap((b) => [...b.body.matchAll(/(--[a-z0-9-]+)\s*:\s*([^;]+);/g)].map((m) => [m[1], m[2].trim()] as const)),
    )
    const unmapped = colorTokens
      .filter((t) => theme.get(`--color-${t.name}`) !== `var(--${t.name})`)
      .map((t) => t.name)
    expect(unmapped).toEqual([])
  })

  it('defines the radius base in :root', () => {
    expect(declared(':root').get('--radius')).toBe(radius)
  })
})
