import { useState, useEffect, useCallback } from 'react'
import { api, getStoredToken, onSessionExpired, UserDTO } from '../services/api'

export function useAuth() {
  const [user, setUser] = useState<UserDTO | null>(null)
  const [loading, setLoading] = useState<boolean>(true)
  const [error, setError] = useState<string | null>(null)
  const [isSessionExpired, setIsSessionExpired] = useState<boolean>(false)

  const checkAuth = useCallback(async () => {
    const token = getStoredToken()
    if (!token) {
      setUser(null)
      setLoading(false)
      return
    }

    try {
      setLoading(true)
      const profile = await api.getProfile()
      setUser(profile.user)
      setError(null)
      setIsSessionExpired(false)
    } catch {
      setUser(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    checkAuth()

    onSessionExpired(() => {
      setIsSessionExpired(true)
    })
  }, [checkAuth])

  const loginWithGoogle = async (credential: string) => {
    setError(null)
    setLoading(true)
    try {
      const res = await api.authenticateWithGoogle(credential)
      setUser(res.user)
      setIsSessionExpired(false)
      return res.user
    } catch (err: unknown) {
      const apiErr = err as { error?: string; message?: string }
      const msg = apiErr.message || 'Authentication failed. Please verify you have an invitation.'
      setError(msg)
      throw new Error(msg)
    } finally {
      setLoading(false)
    }
  }

  const logout = async () => {
    setLoading(true)
    try {
      await api.logout()
    } catch {
      // Ignored - local token cleared in api client
    } finally {
      setUser(null)
      setIsSessionExpired(false)
      setLoading(false)
    }
  }

  return {
    user,
    loading,
    error,
    isSessionExpired,
    setIsSessionExpired,
    loginWithGoogle,
    logout,
    checkAuth,
  }
}
