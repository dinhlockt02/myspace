import React, { useState } from 'react'

interface InviteFormProps {
  isOpen: boolean
  onClose: () => void
  onInvite: (email: string) => Promise<unknown>
  inviting: boolean
  error: string | null
  successEmail: string | null
  onReset: () => void
}

export const InviteForm: React.FC<InviteFormProps> = ({
  isOpen,
  onClose,
  onInvite,
  inviting,
  error,
  successEmail,
  onReset,
}) => {
  const [email, setEmail] = useState('')

  if (!isOpen) return null

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email.trim() || inviting) return

    try {
      await onInvite(email.trim())
      setEmail('')
    } catch {
      // Error handled via props
    }
  }

  const handleClose = () => {
    onReset()
    setEmail('')
    onClose()
  }

  return (
    <div className="modal-backdrop" onClick={handleClose}>
      <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="modal-title-group">
            <span className="modal-icon">✉️</span>
            <h3>Invite a Collaborator</h3>
          </div>
          <button type="button" className="btn-close" onClick={handleClose}>
            ✕
          </button>
        </div>

        <p className="modal-description">
          Authorize a colleague to access Idea Collector with their own isolated workspace. Enter their Google email address below.
        </p>

        <form onSubmit={handleSubmit} className="invite-form">
          <div className="form-group">
            <label htmlFor="invitee-email">Google Email Address</label>
            <input
              id="invitee-email"
              type="email"
              placeholder="collaborator@example.com"
              value={email}
              onChange={(e) => {
                setEmail(e.target.value)
                if (error || successEmail) onReset()
              }}
              className="text-input"
              disabled={inviting}
              required
            />
          </div>

          {error && (
            <div className="form-alert error-alert" role="alert">
              <span>⚠️</span> {error}
            </div>
          )}

          {successEmail && (
            <div className="form-alert success-alert" role="status">
              <span>✅</span> <strong>{successEmail}</strong> has been granted access! They can now sign in using Google SSO.
            </div>
          )}

          <div className="modal-actions">
            <button
              type="button"
              className="btn btn-outline"
              onClick={handleClose}
              disabled={inviting}
            >
              Done
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={!email.trim() || inviting}
            >
              {inviting ? 'Authorizing...' : 'Send Invitation'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
