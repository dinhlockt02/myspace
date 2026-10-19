import { describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Header } from './Header'

describe('Header', () => {
  it('shows the app title', () => {
    render(<Header user={{ id: '1', email: 'a@example.com' }} onLogout={() => {}} />)
    expect(screen.getByRole('heading', { name: 'Idea Collector' })).toBeInTheDocument()
  })

  it('shows the email and the name when there is one', () => {
    render(
      <Header user={{ id: '1', email: 'a@example.com', name: 'Ada Lovelace' }} onLogout={() => {}} />,
    )
    expect(screen.getByText('a@example.com')).toBeInTheDocument()
    expect(screen.getByText('Ada Lovelace')).toBeInTheDocument()
  })

  it('shows only the email when the user has no name', () => {
    render(<Header user={{ id: '1', email: 'a@example.com' }} onLogout={() => {}} />)
    expect(screen.getByText('a@example.com')).toBeInTheDocument()
    expect(screen.queryByText('Ada Lovelace')).not.toBeInTheDocument()
  })

  it('signs out once when the button is clicked', async () => {
    const user = userEvent.setup()
    const onLogout = vi.fn()
    render(<Header user={{ id: '1', email: 'a@example.com' }} onLogout={onLogout} />)

    await user.click(screen.getByRole('button', { name: 'Sign Out' }))

    expect(onLogout).toHaveBeenCalledTimes(1)
  })
})
