import type { StorybookConfig } from '@storybook/react-vite'
import tailwindcss from '@tailwindcss/vite'
import { mergeConfig } from 'vite'

const config: StorybookConfig = {
  stories: ['../src/**/*.stories.@(ts|tsx)'],
  addons: [
    '@storybook/addon-docs',
    '@storybook/addon-a11y',
    '@storybook/addon-themes',
    '@storybook/addon-vitest',
  ],
  framework: '@storybook/react-vite',
  // No usage telemetry from developer machines or CI
  core: { disableTelemetry: true },
  viteFinal: async (viteConfig) =>
    mergeConfig(viteConfig, {
      plugins: [tailwindcss()],
      // Expose STORYBOOK_THEME (light | dark) to the preview, see preview.ts
      envPrefix: ['VITE_', 'STORYBOOK_'],
    }),
}

export default config
