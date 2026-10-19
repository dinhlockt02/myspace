import { afterEach } from 'vitest'
import { cleanup } from '@testing-library/react'
import '@testing-library/jest-dom/vitest'

// Vitest globals are off, so Testing Library cannot register its own cleanup
afterEach(() => {
  cleanup()
})
