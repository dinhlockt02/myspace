import React from 'react'
import { AppHeader, Badge, Button } from '@myspace/ui'
import { Lightbulb, User } from 'lucide-react'
import { UserDTO } from '../services/api'

interface HeaderProps {
  user: UserDTO
  onLogout: () => void
}

export const Header: React.FC<HeaderProps> = ({ user, onLogout }) => {
  return (
    <AppHeader
      brand={
        <>
          <Lightbulb aria-hidden="true" className="size-6 text-foreground" />
          <h1 className="text-xl font-semibold text-foreground">Idea Collector</h1>
        </>
      }
      actions={
        <>
          <Badge
            variant="outline"
            className="h-auto gap-2 py-1.5 text-sm font-normal"
            title={`Signed in as ${user.email}`}
          >
            <User aria-hidden="true" className="size-4" />
            <span className="flex min-w-0 flex-col text-left leading-tight">
              {user.name && <span className="font-medium text-foreground">{user.name}</span>}
              <span className="break-all text-muted-foreground">{user.email}</span>
            </span>
          </Badge>

          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={onLogout}
            title="Sign out of your session"
          >
            Sign Out
          </Button>
        </>
      }
    />
  )
}
