import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { SessionExpiredModal } from './SessionExpiredModal'
import { authService } from '../services/auth'

vi.mock('../services/auth', () => ({
  authService: { initiateGoogleLogin: vi.fn() },
}))

// The current markup is a plain div, so these tests deliberately do not assert role="dialog".
describe('SessionExpiredModal', () => {
  beforeEach(() => {
    vi.mocked(authService.initiateGoogleLogin).mockReset()
  })

  it('renders nothing when closed', () => {
    const { container } = render(<SessionExpiredModal isOpen={false} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('shows the title and the idle-timeout copy when open', () => {
    render(<SessionExpiredModal isOpen />)
    expect(screen.getByRole('heading', { name: 'Session Expired' })).toBeInTheDocument()
    expect(screen.getByText(/1 hour of idle inactivity/)).toBeInTheDocument()
  })

  it('starts Google sign-in when the resume button is clicked', async () => {
    const user = userEvent.setup()
    render(<SessionExpiredModal isOpen />)

    await user.click(screen.getByRole('button', { name: /Sign in with Google to Resume/ }))

    expect(authService.initiateGoogleLogin).toHaveBeenCalledTimes(1)
  })

  it('has no close control: the resume button is the only action', () => {
    render(<SessionExpiredModal isOpen />)
    expect(screen.getAllByRole('button')).toHaveLength(1)
    expect(screen.queryByRole('button', { name: /close/i })).not.toBeInTheDocument()
  })

  it('cannot be dismissed with Escape', async () => {
    const user = userEvent.setup()
    render(<SessionExpiredModal isOpen />)

    await user.keyboard('{Escape}')

    expect(screen.getByRole('heading', { name: 'Session Expired' })).toBeInTheDocument()
  })

  it('cannot be dismissed by clicking outside', () => {
    render(<SessionExpiredModal isOpen />)

    // The events a real click outside the dialog produces. (user-event refuses to click the page
    // while a modal has set pointer-events: none on it, which is itself how outside clicks are
    // blocked, so the events are dispatched directly.)
    for (const type of ['pointerDown', 'mouseDown', 'pointerUp', 'mouseUp', 'click'] as const) {
      fireEvent[type](document.body)
    }

    expect(screen.getByRole('heading', { name: 'Session Expired' })).toBeInTheDocument()
  })
})
