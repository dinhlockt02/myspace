import { useState } from 'react'
import { useAuth } from './hooks/useAuth'
import { useIdeas } from './hooks/useIdeas'
import { useDraft } from './hooks/useDraft'
import { useInvitations } from './hooks/useInvitations'
import { Header } from './components/Header'
import { AuthPrompt } from './components/AuthPrompt'
import { IdeaForm } from './components/IdeaForm'
import { IdeaList } from './components/IdeaList'
import { InviteForm } from './components/InviteForm'
import { SessionExpiredModal } from './components/SessionExpiredModal'
import './App.css'

function App() {
  const {
    user,
    loading: authLoading,
    error: authError,
    isSessionExpired,
    loginWithGoogle,
    logout,
  } = useAuth()

  const {
    ideas,
    loading: ideasLoading,
    submitting,
    submitIdea,
  } = useIdeas(!!user)

  const { draft, setDraft, clearDraft } = useDraft()

  const {
    inviting,
    error: inviteError,
    successEmail: inviteSuccessEmail,
    sendInvitation,
    resetStatus: resetInviteStatus,
  } = useInvitations()

  const [isInviteOpen, setIsInviteOpen] = useState(false)

  if (authLoading) {
    return (
      <div className="app-container app-loading">
        <div className="spinner" />
        <p>Loading application...</p>
      </div>
    )
  }

  if (!user) {
    return (
      <div className="app-container auth-view">
        <AuthPrompt
          onSuccess={loginWithGoogle}
          error={authError}
          loading={authLoading}
        />
      </div>
    )
  }

  return (
    <div className="app-container workspace-view">
      <Header
        user={user}
        onLogout={logout}
        onOpenInvite={() => setIsInviteOpen(true)}
      />

      <main className="workspace-main">
        <div className="workspace-intro">
          <h2>Personal Idea Vault</h2>
          <p>
            Your ideas are strictly private and accessible only by you.
          </p>
        </div>

        <IdeaForm
          draft={draft}
          onDraftChange={setDraft}
          onSubmit={submitIdea}
          onClearDraft={clearDraft}
          submitting={submitting}
        />

        <IdeaList ideas={ideas} loading={ideasLoading} />
      </main>

      <InviteForm
        isOpen={isInviteOpen}
        onClose={() => setIsInviteOpen(false)}
        onInvite={sendInvitation}
        inviting={inviting}
        error={inviteError}
        successEmail={inviteSuccessEmail}
        onReset={resetInviteStatus}
      />

      <SessionExpiredModal
        isOpen={isSessionExpired}
        onSuccess={loginWithGoogle}
      />
    </div>
  )
}

export default App
