import { useState, useEffect, useCallback } from 'react'
import { api, IdeaItem } from '../services/api'

export function useIdeas(isAuthenticated: boolean) {
  const [ideas, setIdeas] = useState<IdeaItem[]>([])
  const [loading, setLoading] = useState<boolean>(false)
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState<boolean>(false)

  const fetchIdeas = useCallback(async () => {
    if (!isAuthenticated) return
    setLoading(true)
    setError(null)
    try {
      const res = await api.listIdeas()
      setIdeas(res.ideas || [])
    } catch (err: unknown) {
      const apiErr = err as { message?: string }
      setError(apiErr.message || 'Failed to load your ideas.')
    } finally {
      setLoading(false)
    }
  }, [isAuthenticated])

  useEffect(() => {
    if (isAuthenticated) {
      fetchIdeas()
    } else {
      setIdeas([])
    }
  }, [isAuthenticated, fetchIdeas])

  const submitIdea = async (content: string) => {
    setSubmitting(true)
    setError(null)
    try {
      const res = await api.submitIdea(content)
      await fetchIdeas()
      return res
    } catch (err: unknown) {
      const apiErr = err as { message?: string }
      const msg = apiErr.message || 'Failed to submit idea.'
      setError(msg)
      throw new Error(msg)
    } finally {
      setSubmitting(false)
    }
  }

  return {
    ideas,
    loading,
    error,
    submitting,
    fetchIdeas,
    submitIdea,
  }
}
