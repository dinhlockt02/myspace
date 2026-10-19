import { describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { IdeaForm } from './IdeaForm'

const MAX = 5000

function setup(overrides: Partial<React.ComponentProps<typeof IdeaForm>> = {}) {
  const props = {
    draft: 'A fresh idea',
    onDraftChange: vi.fn(),
    onSubmit: vi.fn().mockResolvedValue(undefined),
    onClearDraft: vi.fn(),
    submitting: false,
    ...overrides,
  }
  render(<IdeaForm {...props} />)
  return props
}

const submitButton = () => screen.getByRole('button', { name: /^(Submit Idea|Submitting\.\.\.)$/ })

describe('IdeaForm', () => {
  it('disables submit for an empty draft', () => {
    setup({ draft: '' })
    expect(submitButton()).toBeDisabled()
  })

  it('disables submit for a whitespace-only draft', () => {
    setup({ draft: '   \n  ' })
    expect(submitButton()).toBeDisabled()
  })

  it('disables submit when the draft is over 5000 characters', () => {
    setup({ draft: 'a'.repeat(MAX + 1) })
    expect(submitButton()).toBeDisabled()
  })

  it('enables submit for a draft of exactly 5000 characters', () => {
    setup({ draft: 'a'.repeat(MAX) })
    expect(submitButton()).toBeEnabled()
  })

  it('shows the character counter', () => {
    setup({ draft: 'hello' })
    expect(screen.getByText('5 / 5000')).toBeInTheDocument()
  })

  it('reports typing through onDraftChange', async () => {
    const user = userEvent.setup()
    const { onDraftChange } = setup({ draft: '' })

    await user.type(screen.getByRole('textbox'), 'x')

    expect(onDraftChange).toHaveBeenCalledWith('x')
  })

  it('submits the draft, clears it and shows a status message', async () => {
    const user = userEvent.setup()
    const { onSubmit, onClearDraft } = setup({ draft: 'My idea' })

    await user.click(submitButton())

    expect(onSubmit).toHaveBeenCalledWith('My idea')
    await waitFor(() => expect(onClearDraft).toHaveBeenCalledTimes(1))
    expect(await screen.findByRole('status')).toHaveTextContent(
      'Your idea has been recorded securely!',
    )
  })

  it('shows the error message as an alert and keeps the draft when submit fails', async () => {
    const user = userEvent.setup()
    const { onClearDraft } = setup({ onSubmit: vi.fn().mockRejectedValue(new Error('Server said no')) })

    await user.click(submitButton())

    expect(await screen.findByRole('alert')).toHaveTextContent('Server said no')
    expect(onClearDraft).not.toHaveBeenCalled()
  })

  it('falls back to a default message when the error has none', async () => {
    const user = userEvent.setup()
    setup({ onSubmit: vi.fn().mockRejectedValue({}) })

    await user.click(submitButton())

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Failed to submit idea. Please try again.',
    )
  })

  it('shows "Submitting..." and disables the controls while submitting', () => {
    setup({ submitting: true })
    expect(screen.getByRole('button', { name: 'Submitting...' })).toBeDisabled()
    expect(screen.getByRole('textbox')).toBeDisabled()
  })
})
