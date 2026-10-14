import React, { useEffect, useRef, useState } from 'react'

interface AuthPromptProps {
  onSuccess: (credential: string) => Promise<unknown>
  error: string | null
  loading: boolean
}

const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID || ''

export const AuthPrompt: React.FC<AuthPromptProps> = ({ onSuccess, error, loading }) => {
  const btnContainerRef = useRef<HTMLDivElement>(null)
  const [manualToken, setManualToken] = useState('')
  const [showManualInput, setShowManualInput] = useState(false)

  useEffect(() => {
    if (typeof window !== 'undefined' && window.google?.accounts?.id && GOOGLE_CLIENT_ID) {
      window.google.accounts.id.initialize({
        client_id: GOOGLE_CLIENT_ID,
        callback: (response: { credential: string }) => {
          if (response.credential) {
            onSuccess(response.credential)
          }
        },
      })

      if (btnContainerRef.current) {
        window.google.accounts.id.renderButton(btnContainerRef.current, {
          theme: 'filled_black',
          size: 'large',
          text: 'signin_with',
          shape: 'rectangular',
          width: 280,
        })
      }
    }
  }, [onSuccess])

  const handleManualSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (manualToken.trim()) {
      onSuccess(manualToken.trim())
    }
  }

  return (
    <div className="auth-card">
      <div className="auth-header">
        <div className="auth-icon-badge">🔒</div>
        <h2>Welcome to Idea Collector</h2>
        <p className="auth-subtitle">
          Private, invite-only workspace. Sign in with your invited Google account to access your ideas.
        </p>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          <span className="error-icon">⚠️</span>
          <span>{error}</span>
        </div>
      )}

      <div className="auth-actions">
        {loading ? (
          <div className="auth-loading">
            <div className="spinner" />
            <p>Verifying invitation...</p>
          </div>
        ) : (
          <>
            <div ref={btnContainerRef} className="google-btn-wrapper" />

            {/* Fallback option if Google Client ID is configured via token or for testing */}
            {(!GOOGLE_CLIENT_ID || showManualInput) && (
              <form onSubmit={handleManualSubmit} className="manual-token-form">
                <input
                  type="text"
                  placeholder="Paste Google ID Token..."
                  value={manualToken}
                  onChange={(e) => setManualToken(e.target.value)}
                  className="token-input"
                />
                <button type="submit" className="btn btn-primary" disabled={!manualToken.trim()}>
                  Sign In with Token
                </button>
              </form>
            )}

            {!showManualInput && GOOGLE_CLIENT_ID && (
              <button
                type="button"
                className="btn-text-toggle"
                onClick={() => setShowManualInput(true)}
              >
                Having trouble? Use token directly
              </button>
            )}
          </>
        )}
      </div>

      <div className="auth-footer">
        <p>Access is restricted strictly to provisioned or peer-invited Google accounts.</p>
      </div>
    </div>
  )
}
