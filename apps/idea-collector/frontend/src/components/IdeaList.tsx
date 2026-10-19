import React from 'react'
import { Badge, Card, CardContent, CardDescription, CardHeader, CardTitle, Spinner } from '@myspace/ui'
import { Clock, Sparkles } from 'lucide-react'
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
      <section className="grid gap-4">
        <h3 className="text-xl font-semibold">Your Collection</h3>
        <div className="flex items-center justify-center gap-3 py-8 text-muted-foreground">
          <Spinner label="Loading" />
          <p>Loading your ideas...</p>
        </div>
      </section>
    )
  }

  if (ideas.length === 0) {
    return (
      <section className="grid gap-4">
        <h3 className="text-xl font-semibold">Your Collection</h3>
        <Card className="items-center text-center">
          <CardHeader className="items-center">
            <Sparkles aria-hidden="true" className="mb-1 size-8 text-muted-foreground" />
            <CardTitle as="h4">No ideas submitted yet</CardTitle>
            <CardDescription>
              Your private space is empty. Write and submit your first idea above to start building your collection!
            </CardDescription>
          </CardHeader>
        </Card>
      </section>
    )
  }

  return (
    <section className="grid gap-4">
      <div className="flex items-center justify-between gap-4">
        <h3 className="text-xl font-semibold">Your Collection</h3>
        <Badge variant="secondary">
          {ideas.length} {ideas.length === 1 ? 'idea' : 'ideas'}
        </Badge>
      </div>

      <ul className="grid gap-4 sm:grid-cols-2">
        {ideas.map((item) => (
          <li key={item.id}>
            <Card className="h-full gap-3 py-4">
              <CardContent className="grid gap-3">
                <p className="break-words whitespace-pre-wrap">{item.idea}</p>
                <p className="flex items-center gap-1.5 text-sm text-muted-foreground">
                  <Clock aria-hidden="true" className="size-4" />
                  {formatDate(item.server_timestamp || item.client_timestamp)}
                </p>
              </CardContent>
            </Card>
          </li>
        ))}
      </ul>
    </section>
  )
}
