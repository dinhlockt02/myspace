import React from 'react'
import { IdeaItem } from '../services/api'

interface IdeaListProps {
  ideas: IdeaItem[]
  loading: boolean
}

export const IdeaList: React.FC<IdeaListProps> = ({ ideas, loading }) => {
  const formatDate = (timestampMs: number) => {
    if (!timestampMs) return ''
    try {
      const d = new Date(timestampMs)
      return d.toLocaleDateString(undefined, {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
    } catch {
      return ''
    }
  }

  if (loading && ideas.length === 0) {
    return (
      <div className="ideas-section">
        <h3>Your Collection</h3>
        <div className="loading-state">
          <div className="spinner" />
          <p>Loading your ideas...</p>
        </div>
      </div>
    )
  }

  if (ideas.length === 0) {
    return (
      <div className="ideas-section">
        <h3>Your Collection</h3>
        <div className="empty-state-card">
          <div className="empty-state-icon">✨</div>
          <h4>No ideas submitted yet</h4>
          <p>Your private space is empty. Write and submit your first idea above to start building your collection!</p>
        </div>
      </div>
    )
  }

  return (
    <div className="ideas-section">
      <div className="ideas-section-header">
        <h3>Your Collection</h3>
        <span className="badge-count">{ideas.length} {ideas.length === 1 ? 'idea' : 'ideas'}</span>
      </div>

      <div className="ideas-grid">
        {ideas.map((item) => (
          <article key={item.id} className="idea-card">
            <p className="idea-content">{item.idea}</p>
            <div className="idea-meta">
              <span className="idea-time">
                🕒 {formatDate(item.server_timestamp || item.client_timestamp)}
              </span>
            </div>
          </article>
        ))}
      </div>
    </div>
  )
}
