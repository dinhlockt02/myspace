import { describe, expect, it } from 'vitest'

// Enforces FR-013 and SC-001: the app styles itself only through @myspace/ui tokens and components.
const sources = import.meta.glob<string>('./**/*.{tsx,css}', {
  query: '?raw',
  import: 'default',
  eager: true,
})

const rawColor = /#[0-9a-fA-F]{3,8}\b|\brgba?\(|\bhsla?\(/

describe('design system migration', () => {
  it('has removed the legacy App.css', () => {
    expect(Object.keys(sources)).not.toContain('./App.css')
  })

  it('scans the application sources', () => {
    expect(Object.keys(sources)).toContain('./App.tsx')
    expect(Object.keys(sources)).toContain('./index.css')
  })

  it('contains no raw color literals in .tsx or .css files', () => {
    const offenders = Object.entries(sources)
      .filter(([, content]) => rawColor.test(content))
      .map(([path]) => path)

    expect(offenders).toEqual([])
  })
})
