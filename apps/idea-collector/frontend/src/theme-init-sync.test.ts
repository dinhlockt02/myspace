import { describe, expect, it } from 'vitest'
import { themeInitScript } from '@myspace/ui/theme-init'
import indexHtml from '../index.html?raw'

// index.html cannot import the script, so it carries a verbatim copy. This guards that copy against drift.
describe('theme init script in index.html', () => {
  const inlineScripts = [...indexHtml.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1].trim())

  it('is an inline script identical to themeInitScript from @myspace/ui', () => {
    expect(inlineScripts).toContain(themeInitScript.trim())
  })

  it('runs before the Google script and the app entry, so the first paint is themed', () => {
    const init = indexHtml.indexOf(themeInitScript.trim())
    expect(init).toBeGreaterThan(-1)
    expect(init).toBeLessThan(indexHtml.indexOf('accounts.google.com'))
    expect(init).toBeLessThan(indexHtml.indexOf('/src/main.tsx'))
  })

  it('does not hard-code a theme class on <html>', () => {
    expect(indexHtml).not.toMatch(/<html[^>]*class=/)
  })
})
