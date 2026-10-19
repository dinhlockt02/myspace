import type { Preview } from '@storybook/react-vite'
import { withThemeByClassName } from '@storybook/addon-themes'
import '../src/styles/storybook.css'

// The initial theme comes from STORYBOOK_THEME so the test run can be repeated once per theme
// (STORYBOOK_THEME=light | dark) without duplicating stories. Defaults to light.
const initialTheme = import.meta.env.STORYBOOK_THEME === 'dark' ? 'dark' : 'light'

const preview: Preview = {
  parameters: {
    a11y: {
      // Any axe violation fails the test run
      test: 'error',
    },
  },
  decorators: [
    withThemeByClassName({
      themes: { light: '', dark: 'dark' },
      defaultTheme: initialTheme,
    }),
  ],
}

export default preview
