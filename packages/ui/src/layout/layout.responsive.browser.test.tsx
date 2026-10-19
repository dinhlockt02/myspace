import { afterEach, describe, expect, it } from 'vitest'
import { page } from 'vitest/browser'
import { cleanup, render } from '@testing-library/react'
import { composeStories } from '@storybook/react-vite'
import '../styles/storybook.css'
import * as appHeaderStories from './app-header.stories'
import * as pageContainerStories from './page-container.stories'
import * as sidebarLayoutStories from './sidebar-layout.stories'

// SC-004 and FR-007: the layout primitives hold from 320px to 2560px with no horizontal scrolling.
// These need real layout and media queries, so they run in Chromium rather than jsdom.

const WIDTHS = [320, 375, 640, 1024, 2560]
const HEIGHT = 900

const stories = {
  AppHeader: composeStories(appHeaderStories),
  PageContainer: composeStories(pageContainerStories),
  SidebarLayout: composeStories(sidebarLayoutStories),
}

const cases = Object.entries(stories).flatMap(([group, composed]) =>
  Object.entries(composed).map(([name, Story]) => ({ label: `${group} / ${name}`, Story })),
)

const slot = (name: string) => document.querySelector<HTMLElement>(`[data-slot="${name}"]`)!

afterEach(() => cleanup())

describe('responsive layout (SC-004, FR-007)', () => {
  describe.each(WIDTHS)('at %ipx', (width) => {
    it.each(cases)('$label does not scroll horizontally', async ({ Story }) => {
      await page.viewport(width, HEIGHT)
      render(<Story />)

      const root = document.documentElement
      expect(root.clientWidth).toBe(width)
      expect(root.scrollWidth).toBeLessThanOrEqual(root.clientWidth)
    })
  })

  describe('SidebarLayout', () => {
    const { Default } = stories.SidebarLayout

    it('stacks the sidebar above the content below 1024px', async () => {
      await page.viewport(1023, HEIGHT)
      render(<Default />)

      const sidebar = slot('sidebar').getBoundingClientRect()
      const content = slot('sidebar-content').getBoundingClientRect()
      expect(sidebar.bottom).toBeLessThanOrEqual(content.top)
      expect(sidebar.width).toBeCloseTo(content.width, 0)
    })

    it('puts the sidebar beside the content from 1024px', async () => {
      await page.viewport(1024, HEIGHT)
      render(<Default />)

      const sidebar = slot('sidebar').getBoundingClientRect()
      const content = slot('sidebar-content').getBoundingClientRect()
      expect(sidebar.right).toBeLessThanOrEqual(content.left)
      expect(sidebar.top).toBeCloseTo(content.top, 0)
    })
  })

  describe('AppHeader', () => {
    const { WithActions } = stories.AppHeader

    it('wraps the actions under the brand below 640px', async () => {
      await page.viewport(639, HEIGHT)
      render(<WithActions />)

      const brand = slot('app-header-brand').getBoundingClientRect()
      const actions = slot('app-header-actions').getBoundingClientRect()
      expect(actions.top).toBeGreaterThanOrEqual(brand.bottom)
    })

    it('keeps the actions on the brand row from 640px', async () => {
      await page.viewport(640, HEIGHT)
      render(<WithActions />)

      const brand = slot('app-header-brand').getBoundingClientRect()
      const actions = slot('app-header-actions').getBoundingClientRect()
      expect(actions.top).toBeLessThan(brand.bottom)
      expect(actions.left).toBeGreaterThanOrEqual(brand.right)
    })
  })
})
