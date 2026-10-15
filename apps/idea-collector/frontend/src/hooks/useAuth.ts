import { useState, useEffect, useCallback } from 'react'
import { authService } from '../services/auth'
import { onSessionExpired, UserDTO } from '../services/api'

export function useAuth() {
  const [user, setUser] = useState<UserDTO | null>(null)
  const [loading, setLoading] = useState<boolean>(true)
  const [error, setError] = useState<string | null>(null)
  const [isSessionExpired, setIsSessionExpired] = useState<boolean>(false)

  const checkAuth = useCallback(async () => {
    setLoading(true)
    try {
      // 1. Check for OAuth code callback in URL query parameters
      const urlParams = new URLSearchParams(window.location.search)
      const code = urlParams.get('code')
      const state = urlParams.get('state')
      const oauthError = urlParams.get('error_description') || urlParams.get('error')

      if (oauthError) {
        window.history.replaceState({}, document.title, window.location.pathname)
        setError(`Authentication was canceled or encountered an issue: ${oauthError}`)
        setUser(null)
        setLoading(false)
        return
      }

      if (code && state) {
        window.history.replaceState({}, document.title, window.location.pathname)
        const claims = await authService.handleCallback(code, state)
        setUser({
          id: claims.sub,
          email: claims.email,
          name: claims.name,
        })
        setError(null)
        setIsSessionExpired(false)
        setLoading(false)
        return
      }

      // 2. Check existing stored Cognito session
      const existingUser = authService.getCurrentUser()
      if (existingUser) {
        setUser({
          id: existingUser.sub,
          email: existingUser.email,
          name: existingUser.name,
        })
        setError(null)
        setIsSessionExpired(false)
        setLoading(false)
        return
      }

      // 3. Attempt token refresh if refresh token exists
      const refreshedToken = await authService.refreshTokens()
      if (refreshedToken) {
        const refreshedUser = authService.getCurrentUser()
        if (refreshedUser) {
          setUser({
            id: refreshedUser.sub,
            email: refreshedUser.email,
            name: refreshedUser.name,
          })
          setError(null)
          setIsSessionExpired(false)
          setLoading(false)
          return
        }
      }

      setUser(null)
    } catch (err: unknown) {
      console.error('Auth verification error:', err)
      const message = err instanceof Error ? err.message : 'Authentication failed'
      setError(message)
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

  const logout = async () => {
    setLoading(true)
    try {
      authService.clearTokens()
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
    logout,
    checkAuth,
  }
}
