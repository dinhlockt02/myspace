import { afterEach, describe, expect, it } from 'vitest'
import themeCss from './theme.css?raw'
import consumerCss from './fixtures/consumer.css?inline'
import consumerWithResetCss from './fixtures/consumer-with-reset.css?inline'

// FR-009 and the "Side-by-Side Coexistence with Legacy Views" edge case: adding the design system
// to a page that still has plain, un-migrated HTML must not change how that HTML looks.

const SAMPLE = `
  <div id="legacy">
    <h1>Heading</h1>
    <p>Paragraph with a <a href="#x">link</a>.</p>
    <button type="button">Button</button>
    <input type="text" value="field" />
    <ul><li>item</li></ul>
    <table><tbody><tr><td>cell</td></tr></tbody></table>
  </div>`

const PROPS = [
  'display', 'box-sizing', 'margin-top', 'margin-bottom', 'padding-top', 'padding-left',
  'font-family', 'font-size', 'font-weight', 'line-height', 'color', 'background-color',
  'border-top-width', 'border-top-style', 'list-style-type', 'text-decoration-line', 'cursor',
]

const installed: HTMLStyleElement[] = []

function snapshot(): string[] {
  const root = document.getElementById('legacy')!
  return [...root.querySelectorAll('*')].map((el) => {
    const style = getComputedStyle(el)
    return `${el.tagName}: ${PROPS.map((p) => style.getPropertyValue(p)).join(' | ')}`
  })
}

function addStyles(css: string): void {
  const style = document.createElement('style')
  style.textContent = css
  document.head.append(style)
  installed.push(style)
}

afterEach(() => {
  installed.splice(0).forEach((s) => s.remove())
  document.body.innerHTML = ''
})

describe('coexistence with un-migrated HTML', () => {
  it('theme.css alone leaves plain HTML untouched', () => {
    document.body.innerHTML = SAMPLE
    const before = snapshot()
    // Tailwind directives (@import, @theme, @custom-variant) are resolved by the build, not the
    // browser, so inject only the plain CSS rules a page would actually receive
    addStyles(themeCss.replace(/@import[^;]*;/g, ''))
    expect(snapshot()).toEqual(before)
  })

  it('a consumer stylesheet without the base reset leaves plain HTML untouched', () => {
    document.body.innerHTML = SAMPLE
    const before = snapshot()
    addStyles(consumerCss)
    expect(snapshot()).toEqual(before)
  })

  it('negative control: opting in to the base reset does change plain HTML', () => {
    document.body.innerHTML = SAMPLE
    const before = snapshot()
    addStyles(consumerWithResetCss)
    expect(snapshot()).not.toEqual(before)
  })
})
