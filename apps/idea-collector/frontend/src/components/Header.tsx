import React from 'react'
import { UserDTO } from '../services/api'

interface HeaderProps {
  user: UserDTO
  onLogout: () => void
}

export const Header: React.FC<HeaderProps> = ({ user, onLogout }) => {
  return (
    <header className="app-header">
      <div className="header-brand">
        <span className="brand-logo">💡</span>
        <h1>Idea Collector</h1>
      </div>

      <div className="header-user-section">
        <div className="user-badge" title={`Signed in as ${user.email}`}>
          <span className="user-icon">👤</span>
          <div className="user-info">
            {user.name && <span className="user-name">{user.name}</span>}
            <span className="user-email">{user.email}</span>
          </div>
        </div>

        <button
          type="button"
          className="btn btn-outline btn-sm"
          onClick={onLogout}
          title="Sign out of your session"
        >
          Sign Out
        </button>
      </div>
    </header>
  )
}
