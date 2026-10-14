import { useState, useEffect, useCallback } from 'react'

const DRAFT_STORAGE_KEY = 'ideacollector_draft_content'

export function useDraft() {
  const [draft, setDraftState] = useState<string>(() => {
    return localStorage.getItem(DRAFT_STORAGE_KEY) || ''
  })

  const setDraft = useCallback((text: string) => {
    setDraftState(text)
    if (text) {
      localStorage.setItem(DRAFT_STORAGE_KEY, text)
    } else {
      localStorage.removeItem(DRAFT_STORAGE_KEY)
    }
  }, [])

  const clearDraft = useCallback(() => {
    setDraftState('')
    localStorage.removeItem(DRAFT_STORAGE_KEY)
  }, [])

  // Sync if another tab or window changes the draft
  useEffect(() => {
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === DRAFT_STORAGE_KEY) {
        setDraftState(e.newValue || '')
      }
    }
    window.addEventListener('storage', handleStorageChange)
    return () => window.removeEventListener('storage', handleStorageChange)
  }, [])

  return {
    draft,
    setDraft,
    clearDraft,
  }
}
