import React, { useEffect, useRef, useState } from 'react'

interface SessionExpiredModalProps {
  isOpen: boolean
  onSuccess: (credential: string) => Promise<unknown>
}

const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID || ''

export const SessionExpiredModal: React.FC<SessionExpiredModalProps> = ({ isOpen, onSuccess }) => {
  const btnRef = useRef<HTMLDivElement>(null)
  const [manualToken, setManualToken] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (isOpen && typeof window !== 'undefined' && window.google?.accounts?.id && GOOGLE_CLIENT_ID) {
      window.google.accounts.id.initialize({
        client_id: GOOGLE_CLIENT_ID,
        callback: async (response: { credential: string }) => {
          if (response.credential) {
            setLoading(true)
            setError(null)
            try {
              await onSuccess(response.credential)
            } catch (err: unknown) {
              const apiErr = err as { message?: string }
              setError(apiErr.message || 'Re-authentication failed.')
            } finally {
              setLoading(false)
            }
          }
        },
      })

      if (btnRef.current) {
        window.google.accounts.id.renderButton(btnRef.current, {
          theme: 'filled_black',
          size: 'large',
          text: 'signin',
          shape: 'rectangular',
          width: 260,
        })
      }
    }
  }, [isOpen, onSuccess])

  if (!isOpen) return null

  const handleManualSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!manualToken.trim()) return

    setLoading(true)
    setError(null)
    try {
      await onSuccess(manualToken.trim())
    } catch (err: unknown) {
      const apiErr = err as { message?: string }
      setError(apiErr.message || 'Re-authentication failed.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="modal-backdrop">
      <div className="modal-dialog session-expired-dialog">
        <div className="modal-header">
          <div className="modal-title-group">
            <span className="modal-icon">⏳</span>
            <h3>Session Expired</h3>
          </div>
        </div>

        <div className="modal-body">
          <p>
            Your session has timed out due to <strong>1 hour of idle inactivity</strong>.
          </p>
          <div className="preserved-draft-badge">
            <span>🛡️</span>
            <span>Your unsubmitted draft idea has been safely preserved! Sign in below to continue writing and submit.</span>
          </div>

          {error && (
            <div className="form-alert error-alert" role="alert">
              <span>⚠️</span> {error}
            </div>
          )}

          <div className="reauth-actions">
            {loading ? (
              <div className="spinner" />
            ) : (
              <>
                <div ref={btnRef} className="google-btn-wrapper" />
                <form onSubmit={handleManualSubmit} className="manual-token-form">
                  <input
                    type="text"
                    placeholder="Or enter Google ID Token..."
                    value={manualToken}
                    onChange={(e) => setManualToken(e.target.value)}
                    className="text-input"
                  />
                  <button type="submit" className="btn btn-primary" disabled={!manualToken.trim()}>
                    Sign In
                  </button>
                </form>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
