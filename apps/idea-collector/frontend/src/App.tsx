import { PageContainer, Spinner } from '@myspace/ui'
import { useAuth } from './hooks/useAuth'
import { useIdeas } from './hooks/useIdeas'
import { useDraft } from './hooks/useDraft'
import { Header } from './components/Header'
import { AuthPrompt } from './components/AuthPrompt'
import { IdeaForm } from './components/IdeaForm'
import { IdeaList } from './components/IdeaList'
import { SessionExpiredModal } from './components/SessionExpiredModal'

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
      <PageContainer className="flex min-h-svh flex-col items-center justify-center gap-4">
        <Spinner size="lg" label="Loading application" />
        <p className="text-muted-foreground">Loading application...</p>
      </PageContainer>
    )
  }

  if (!user) {
    return (
      <PageContainer className="flex min-h-svh items-center justify-center py-8">
        <AuthPrompt
          error={authError}
          loading={authLoading}
        />
      </PageContainer>
    )
  }

  return (
    <PageContainer>
      <Header
        user={user}
        onLogout={logout}
      />

      <main className="grid gap-8 py-8">
        <div className="grid gap-1">
          <h2 className="text-2xl font-semibold">Personal Idea Vault</h2>
          <p className="text-muted-foreground">
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
    </PageContainer>
  )
}

export default App
