import { describe, expect, it } from 'vitest'
import { parse, wcagContrast } from 'culori'
import { colorTokens, contrastPairs, findMissingModes, type Mode, type Token } from './tokens'

const THRESHOLD = { text: 4.5, control: 3 } as const
const MODES: Mode[] = ['light', 'dark']

function valueOf(name: string, mode: Mode): string {
  const token = colorTokens.find((t) => t.name === name)
  if (!token) throw new Error(`Unknown token in a contrast pair: ${name}`)
  return token[mode]
}

describe('design tokens: WCAG 2.1 AA contrast', () => {
  it('lists the 26 required pairs from the contract', () => {
    expect(contrastPairs).toHaveLength(26)
  })

  it('defines every color token in both modes', () => {
    expect(findMissingModes(colorTokens)).toEqual([])
  })

  it('reports a token that lacks a mode value (the check can fail)', () => {
    const broken = [{ name: 'broken', group: 'surface', light: 'oklch(1 0 0)', dark: '' }] as Token[]
    expect(findMissingModes(broken)).toEqual(['broken (dark)'])
  })

  for (const mode of MODES) {
    describe(`${mode} mode`, () => {
      for (const pair of contrastPairs) {
        const need = THRESHOLD[pair.kind]
        it(`${pair.foreground} on ${pair.background} is at least ${need}:1`, () => {
          const fg = parse(valueOf(pair.foreground, mode))
          const bg = parse(valueOf(pair.background, mode))
          expect(fg, `${pair.foreground} must be a valid color`).toBeDefined()
          expect(bg, `${pair.background} must be a valid color`).toBeDefined()
          expect(wcagContrast(fg!, bg!)).toBeGreaterThanOrEqual(need)
        })
      }
    })
  }
})
