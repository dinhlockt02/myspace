import { useState } from 'react'

const API_URL = import.meta.env.VITE_API_URL || ''

function App() {
  const [idea, setIdea] = useState('')
  const [status, setStatus] = useState<'idle' | 'submitting' | 'success' | 'error'>('idle')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!idea.trim()) return

    setStatus('submitting')
    try {
      await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idea, timestamp: new Date().toISOString() }),
      })
      setStatus('success')
      setIdea('')
    } catch {
      setStatus('error')
    }
  }

  return (
    <div style={{ maxWidth: 600, margin: '2rem auto', padding: '0 1rem' }}>
      <h1>Idea Collector</h1>
      <form onSubmit={handleSubmit}>
        <textarea
          value={idea}
          onChange={(e) => setIdea(e.target.value)}
          placeholder="Share your idea..."
          rows={6}
          style={{ width: '100%', padding: '0.5rem', fontSize: '1rem' }}
          disabled={status === 'submitting'}
        />
        <button type="submit" disabled={status === 'submitting' || !idea.trim()}>
          {status === 'submitting' ? 'Submitting...' : 'Submit Idea'}
        </button>
      </form>
      {status === 'success' && <p style={{ color: 'green' }}>Idea submitted!</p>}
      {status === 'error' && <p style={{ color: 'red' }}>Failed to submit. Try again.</p>}
    </div>
  )
}

export default App
