import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { storybookTest } from '@storybook/addon-vitest/vitest-plugin'
import { playwright } from '@vitest/browser-playwright'

const dirname = path.dirname(fileURLToPath(import.meta.url))

// A fresh object per project: Vitest annotates the instances, so projects must not share one
const browser = () => ({
  enabled: true,
  headless: true,
  provider: playwright(),
  instances: [{ browser: 'chromium' as const }],
})

export default defineConfig({
  envPrefix: ['VITE_', 'STORYBOOK_'],
  test: {
    projects: [
      {
        // Pure logic and jsdom tests: tokens, theme provider, cn, file checks
        plugins: [react()],
        test: {
          name: 'unit',
          environment: 'jsdom',
          include: ['src/**/*.test.{ts,tsx}'],
          exclude: ['src/**/*.browser.test.{ts,tsx}'],
        },
      },
      {
        // Tests that need real layout and computed styles (coexistence, responsive overflow)
        plugins: [react(), tailwindcss()],
        test: {
          name: 'browser',
          include: ['src/**/*.browser.test.{ts,tsx}'],
          browser: browser(),
        },
      },
      {
        // Runs every story: axe accessibility checks and play (keyboard) tests
        plugins: [storybookTest({ configDir: path.join(dirname, '.storybook') })],
        test: {
          name: 'storybook',
          // Preview annotations (including the a11y addon) are applied automatically
          // by @storybook/addon-vitest since Storybook 10.3, so no setup file is needed.
          browser: browser(),
        },
      },
    ],
  },
})
