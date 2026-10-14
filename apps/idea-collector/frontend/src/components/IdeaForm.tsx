import React, { useState } from 'react'

interface IdeaFormProps {
  draft: string
  onDraftChange: (text: string) => void
  onSubmit: (content: string) => Promise<unknown>
  onClearDraft: () => void
  submitting: boolean
}

const MAX_CHAR_COUNT = 5000

export const IdeaForm: React.FC<IdeaFormProps> = ({
  draft,
  onDraftChange,
  onSubmit,
  onClearDraft,
  submitting,
}) => {
  const [successNotice, setSuccessNotice] = useState<string | null>(null)
  const [formError, setFormError] = useState<string | null>(null)

  const trimmed = draft.trim()
  const charCount = draft.length
  const isOverLimit = charCount > MAX_CHAR_COUNT
  const isValid = trimmed.length > 0 && !isOverLimit

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!isValid || submitting) return

    setFormError(null)
    setSuccessNotice(null)
    try {
      await onSubmit(draft)
      onClearDraft()
      setSuccessNotice('Your idea has been recorded securely!')
      setTimeout(() => setSuccessNotice(null), 4000)
    } catch (err: unknown) {
      const apiErr = err as { message?: string }
      setFormError(apiErr.message || 'Failed to submit idea. Please try again.')
    }
  }

  return (
    <div className="card idea-form-card">
      <div className="card-header">
        <h3>💡 Capture New Idea</h3>
        <span className={`char-counter ${isOverLimit ? 'over-limit' : ''}`}>
          {charCount} / {MAX_CHAR_COUNT}
        </span>
      </div>

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <textarea
            value={draft}
            onChange={(e) => {
              onDraftChange(e.target.value)
              if (formError) setFormError(null)
              if (successNotice) setSuccessNotice(null)
            }}
            placeholder="Type your innovative thought or concept here..."
            rows={5}
            className="idea-textarea"
            disabled={submitting}
            maxLength={MAX_CHAR_COUNT + 100}
          />
        </div>

        {formError && (
          <div className="form-alert error-alert" role="alert">
            <span>⚠️</span> {formError}
          </div>
        )}

        {successNotice && (
          <div className="form-alert success-alert" role="status">
            <span>✅</span> {successNotice}
          </div>
        )}

        <div className="form-actions">
          <button
            type="submit"
            className="btn btn-primary"
            disabled={!isValid || submitting}
          >
            {submitting ? 'Submitting...' : 'Submit Idea'}
          </button>
        </div>
      </form>
    </div>
  )
}
