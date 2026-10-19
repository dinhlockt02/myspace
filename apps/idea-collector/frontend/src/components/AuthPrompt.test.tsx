import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { AuthPrompt } from './AuthPrompt'
import { authService } from '../services/auth'

vi.mock('../services/auth', () => ({
  authService: { initiateGoogleLogin: vi.fn() },
}))

// Characterization tests: they describe the behavior that must survive the design-system migration.
describe('AuthPrompt', () => {
  beforeEach(() => {
    vi.mocked(authService.initiateGoogleLogin).mockReset()
  })

  it('shows the welcome heading', () => {
    render(<AuthPrompt error={null} loading={false} />)
    expect(
      screen.getByRole('heading', { name: 'Welcome to Idea Collector' }),
    ).toBeInTheDocument()
  })

  it('starts Google sign-in once when the button is clicked', async () => {
    const user = userEvent.setup()
    render(<AuthPrompt error={null} loading={false} />)

    await user.click(screen.getByRole('button', { name: 'Sign in with Google' }))

    expect(authService.initiateGoogleLogin).toHaveBeenCalledTimes(1)
  })

  it('shows an error as an alert', () => {
    render(<AuthPrompt error="Sign-in failed" loading={false} />)
    expect(screen.getByRole('alert')).toHaveTextContent('Sign-in failed')
  })

  it('shows no alert without an error', () => {
    render(<AuthPrompt error={null} loading={false} />)
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
  })

  it('shows progress and hides the sign-in button while loading', () => {
    render(<AuthPrompt error={null} loading />)
    expect(screen.getByText('Signing in...')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Sign in with Google' })).not.toBeInTheDocument()
  })
})
