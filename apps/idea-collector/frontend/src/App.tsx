import { useAuth } from './hooks/useAuth'
import { useIdeas } from './hooks/useIdeas'
import { useDraft } from './hooks/useDraft'
import { Header } from './components/Header'
import { AuthPrompt } from './components/AuthPrompt'
import { IdeaForm } from './components/IdeaForm'
import { IdeaList } from './components/IdeaList'
import { SessionExpiredModal } from './components/SessionExpiredModal'
import './App.css'

function App() {
  const {
    user,
    loading: authLoading,
    error: authError,
    isSessionExpired,
    logout,
  } = useAuth()

  const {
    ideas,
    loading: ideasLoading,
    submitting,
    submitIdea,
  } = useIdeas(!!user)

  const { draft, setDraft, clearDraft } = useDraft()

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

      <SessionExpiredModal
        isOpen={isSessionExpired}
        onSuccess={() => window.location.reload()}
      />
    </div>
  )
}

export default App
